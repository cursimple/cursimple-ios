import CurSimpleCore
import Foundation
import Observation

/// Installed school plugins: manifest plus the entry script, kept on disk.
@MainActor
@Observable
final class PluginStore {

    struct InstalledPlugin: Identifiable, Sendable {
        let manifest: PluginManifest
        let entryScript: String

        var id: String { manifest.id }
    }

    private(set) var plugins: [InstalledPlugin] = []
    private(set) var lastError: String?

    private let directory: URL

    init(directory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = directory
            ?? base.appendingPathComponent("CurSimple/Plugins", isDirectory: true)
        load()
    }

    func load() {
        plugins = []
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for folder in folders where folder.hasDirectoryPath {
            let manifestURL = folder.appendingPathComponent("manifest.json")
            let entryURL = folder.appendingPathComponent("entry.js")
            guard let manifestData = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: manifestData),
                  let entryData = try? Data(contentsOf: entryURL),
                  let script = String(data: entryData, encoding: .utf8) else {
                continue
            }
            plugins.append(InstalledPlugin(manifest: manifest, entryScript: script))
        }
        plugins.sort { $0.manifest.name < $1.manifest.name }
    }

    /// Validate and install a bundle archive; replaces an existing version.
    func install(archive: Data, hostVersion: String) -> InstalledPlugin? {
        lastError = nil
        do {
            let entries = try ZipArchive.read(archive)
            let files = Dictionary(uniqueKeysWithValues: entries.map { ($0.path, $0.data) })

            guard let manifestData = files["manifest.json"] else {
                throw PluginInstallError.invalidManifest
            }
            let manifest = try JSONDecoder().decode(PluginManifest.self, from: manifestData)
            let validated = try validatePluginManifest(
                manifest,
                availableFiles: Set(files.keys),
                hostVersion: hostVersion
            )

            if let checksumData = files["checksums.json"] {
                let declared = try JSONDecoder().decode([String: String].self, from: checksumData)
                try verifyPluginChecksums(files: files, declared: declared)
            }

            guard let entryData = files[validated.entry],
                  let script = String(data: entryData, encoding: .utf8) else {
                throw PluginInstallError.missingEntry(validated.entry)
            }

            let folder = directory.appendingPathComponent(validated.id, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try manifestData.write(to: folder.appendingPathComponent("manifest.json"), options: .atomic)
            try Data(script.utf8).write(to: folder.appendingPathComponent("entry.js"), options: .atomic)

            let installed = InstalledPlugin(manifest: validated, entryScript: script)
            plugins.removeAll { $0.id == installed.id }
            plugins.append(installed)
            plugins.sort { $0.manifest.name < $1.manifest.name }
            return installed
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func uninstall(id: String) {
        let folder = directory.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        plugins.removeAll { $0.id == id }
    }
}
