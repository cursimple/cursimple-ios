import Foundation
import Testing
@testable import CurSimpleCore

@Suite("Zip archive")
struct ZipArchiveTests {

    /// Build a ZIP in memory so the test needs no external tools.
    private func makeZip(_ files: [(path: String, content: String)]) -> Data {
        var local = Data()
        var central = Data()
        var offsets: [Int] = []

        for file in files {
            offsets.append(local.count)
            let name = Data(file.path.utf8)
            let payload = Data(file.content.utf8)
            let crc = Gzip.crc32(payload)

            local.append(contentsOf: le32(0x04034b50))
            local.append(contentsOf: le16(20))
            local.append(contentsOf: le16(0))
            local.append(contentsOf: le16(0)) // stored
            local.append(contentsOf: le16(0))
            local.append(contentsOf: le16(0))
            local.append(contentsOf: le32(crc))
            local.append(contentsOf: le32(UInt32(payload.count)))
            local.append(contentsOf: le32(UInt32(payload.count)))
            local.append(contentsOf: le16(UInt16(name.count)))
            local.append(contentsOf: le16(0))
            local.append(name)
            local.append(payload)
        }

        for (index, file) in files.enumerated() {
            let name = Data(file.path.utf8)
            let payload = Data(file.content.utf8)
            central.append(contentsOf: le32(0x02014b50))
            central.append(contentsOf: le16(20))
            central.append(contentsOf: le16(20))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le32(Gzip.crc32(payload)))
            central.append(contentsOf: le32(UInt32(payload.count)))
            central.append(contentsOf: le32(UInt32(payload.count)))
            central.append(contentsOf: le16(UInt16(name.count)))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le16(0))
            central.append(contentsOf: le32(0))
            central.append(contentsOf: le32(UInt32(offsets[index])))
            central.append(name)
        }

        var archive = local
        let centralOffset = archive.count
        archive.append(central)
        archive.append(contentsOf: le32(0x06054b50))
        archive.append(contentsOf: le16(0))
        archive.append(contentsOf: le16(0))
        archive.append(contentsOf: le16(UInt16(files.count)))
        archive.append(contentsOf: le16(UInt16(files.count)))
        archive.append(contentsOf: le32(UInt32(central.count)))
        archive.append(contentsOf: le32(UInt32(centralOffset)))
        archive.append(contentsOf: le16(0))
        return archive
    }

    private func le16(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private func le32(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ]
    }

    @Test("Stored entries read back with their paths")
    func storedEntries() throws {
        let archive = makeZip([
            ("manifest.json", #"{"id":"edu.example.schedule"}"#),
            ("main.js", "console.log(1)"),
        ])
        let entries = try ZipArchive.read(archive)
        #expect(entries.map(\.path) == ["manifest.json", "main.js"])
        #expect(String(data: entries[1].data, encoding: .utf8) == "console.log(1)")
    }

    @Test("Traversal paths are rejected")
    func unsafePath() {
        let archive = makeZip([("../evil.js", "x")])
        #expect(throws: PluginInstallError.unsafePath("../evil.js")) {
            try ZipArchive.read(archive)
        }
    }

    @Test("Non-zip data is rejected")
    func notZip() {
        #expect(throws: ZipArchive.ReadError.notZip) {
            try ZipArchive.read(Data("plain text, definitely not a zip".utf8))
        }
    }

    @Test("Size limits stop oversized entries")
    func tooLarge() {
        let archive = makeZip([("big.bin", String(repeating: "a", count: 4096))])
        #expect(throws: ZipArchive.ReadError.tooLarge) {
            try ZipArchive.read(archive, maxEntryBytes: 1024)
        }
    }
}
