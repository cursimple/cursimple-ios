import CryptoKit
import Foundation

public enum PluginPermission: String, Codable, CaseIterable, Sendable, Identifiable {
    case webNavigate = "web.navigate"
    case webReadDOM = "web.read_dom"
    case webReadCookies = "web.read_cookies"
    case webInjectScript = "web.inject_script"
    case webCapturePacket = "web.capture_packet"
    case networkFetch = "network.fetch"
    case scheduleWrite = "schedule.write"
    case storagePlugin = "storage.plugin"
    case componentUse = "component.use"
    case feedWrite = "feed.write"
    case notificationReceive = "notification.receive"
    case storageSecure = "storage.secure"
    case networkProxy = "network.proxy"

    public var id: String { rawValue }

    public var localizationKey: String { "plugin.permission.\(rawValue)" }
}

public enum PluginKind: String, Codable, Sendable {
    case schedule
    case `extension`
}

public struct PluginRuntimeLimits: Codable, Hashable, Sendable {

    public var timeoutMs: Int
    public var maxCourses: Int
    public var maxStorageBytes: Int
    public var maxCapturedTextBytes: Int
    public var maxOutputBytes: Int

    public init(
        timeoutMs: Int = 60_000,
        maxCourses: Int = 1_000,
        maxStorageBytes: Int = 1_048_576,
        maxCapturedTextBytes: Int = 524_288,
        maxOutputBytes: Int = 1_048_576
    ) {
        self.timeoutMs = timeoutMs
        self.maxCourses = maxCourses
        self.maxStorageBytes = maxStorageBytes
        self.maxCapturedTextBytes = maxCapturedTextBytes
        self.maxOutputBytes = maxOutputBytes
    }

    private enum CodingKeys: String, CodingKey {
        case timeoutMs, maxCourses, maxStorageBytes, maxCapturedTextBytes, maxOutputBytes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PluginRuntimeLimits()
        timeoutMs = try container.decodeIfPresent(Int.self, forKey: .timeoutMs) ?? defaults.timeoutMs
        maxCourses = try container.decodeIfPresent(Int.self, forKey: .maxCourses) ?? defaults.maxCourses
        maxStorageBytes = try container.decodeIfPresent(Int.self, forKey: .maxStorageBytes) ?? defaults.maxStorageBytes
        maxCapturedTextBytes = try container.decodeIfPresent(Int.self, forKey: .maxCapturedTextBytes)
            ?? defaults.maxCapturedTextBytes
        maxOutputBytes = try container.decodeIfPresent(Int.self, forKey: .maxOutputBytes) ?? defaults.maxOutputBytes
    }
}

public struct PluginManifest: Codable, Sendable {

    public var id: String
    public var name: String
    public var publisher: String
    public var version: String
    public var versionCode: Int
    public var apiVersion: Int?
    public var entry: String
    public var permissions: [PluginPermission]
    public var limits: PluginRuntimeLimits
    public var allowedHosts: [String]
    public var startUrl: String?
    public var description: String
    public var minHostVersion: String
    public var kind: PluginKind

    public init(
        id: String,
        name: String,
        publisher: String = "",
        version: String,
        versionCode: Int,
        apiVersion: Int? = nil,
        entry: String,
        permissions: [PluginPermission] = [],
        limits: PluginRuntimeLimits = .init(),
        allowedHosts: [String] = [],
        startUrl: String? = nil,
        description: String = "",
        minHostVersion: String = "0.1.0",
        kind: PluginKind = .schedule
    ) {
        self.id = id
        self.name = name
        self.publisher = publisher
        self.version = version
        self.versionCode = versionCode
        self.apiVersion = apiVersion
        self.entry = entry
        self.permissions = permissions
        self.limits = limits
        self.allowedHosts = allowedHosts
        self.startUrl = startUrl
        self.description = description
        self.minHostVersion = minHostVersion
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, publisher, version, versionCode, apiVersion, entry, permissions
        case limits, allowedHosts, startUrl, description, minHostVersion, kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher) ?? ""
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "0.0.0"
        versionCode = try container.decodeIfPresent(Int.self, forKey: .versionCode) ?? 0
        apiVersion = try container.decodeIfPresent(Int.self, forKey: .apiVersion)
        entry = try container.decodeIfPresent(String.self, forKey: .entry) ?? "main.js"
        permissions = (try? container.decodeIfPresent([PluginPermission].self, forKey: .permissions)) ?? []
        limits = (try? container.decodeIfPresent(PluginRuntimeLimits.self, forKey: .limits)) ?? .init()
        allowedHosts = try container.decodeIfPresent([String].self, forKey: .allowedHosts) ?? []
        startUrl = try container.decodeIfPresent(String.self, forKey: .startUrl)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        minHostVersion = try container.decodeIfPresent(String.self, forKey: .minHostVersion) ?? "0.1.0"
        kind = (try? container.decodeIfPresent(PluginKind.self, forKey: .kind)) ?? .schedule
    }

    public func has(_ permission: PluginPermission) -> Bool {
        permissions.contains(permission)
    }
}

/// API level this host implements.
public let supportedPluginApiVersion = 12

public enum PluginInstallError: Error, Equatable, Sendable {
    case invalidManifest
    case unsafeId
    case missingEntry(String)
    case unsupportedApi(Int?)
    case hostTooOld(required: String)
    case extensionRequiresApi3
    case checksumMismatch(String)
    case unsafePath(String)
    case tooLarge
    case hostOutsideAllowedHosts(String)
}

/// Validate a plugin id: lowercase letters, digits, dots, dashes; must contain a dot.
public func isValidPluginID(_ id: String) -> Bool {
    guard id.count >= 3, id.count <= 128, id.contains(".") else { return false }
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-_")
    return id.unicodeScalars.allSatisfy { allowed.contains($0) }
}

/// Normalize a package path, rejecting absolute paths, traversal and backslashes.
public func normalizePluginPath(_ raw: String) throws -> String {
    guard !raw.isEmpty, !raw.hasPrefix("/"), !raw.contains("\\"), !raw.contains("\0") else {
        throw PluginInstallError.unsafePath(raw)
    }
    var parts: [String] = []
    for component in raw.split(separator: "/", omittingEmptySubsequences: true) {
        if component == "." { continue }
        if component == ".." { throw PluginInstallError.unsafePath(raw) }
        parts.append(String(component))
    }
    guard !parts.isEmpty else { throw PluginInstallError.unsafePath(raw) }
    return parts.joined(separator: "/")
}

/// Compare dotted versions numerically, treating a prerelease suffix as lower.
public func comparePluginVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let lhsParts = lhs.split(separator: "-").map(String.init)
    let rhsParts = rhs.split(separator: "-").map(String.init)
    let lhsNumbers = (lhsParts.first ?? "").split(separator: ".").map { Int($0) ?? 0 }
    let rhsNumbers = (rhsParts.first ?? "").split(separator: ".").map { Int($0) ?? 0 }

    for index in 0..<max(lhsNumbers.count, rhsNumbers.count) {
        let left = index < lhsNumbers.count ? lhsNumbers[index] : 0
        let right = index < rhsNumbers.count ? rhsNumbers[index] : 0
        if left != right { return left < right ? .orderedAscending : .orderedDescending }
    }
    let lhsPre = lhsParts.count > 1
    let rhsPre = rhsParts.count > 1
    if lhsPre != rhsPre { return lhsPre ? .orderedAscending : .orderedDescending }
    return .orderedSame
}

/// Validate a manifest against this host and the package's file list.
public func validatePluginManifest(
    _ manifest: PluginManifest,
    availableFiles: Set<String>,
    hostVersion: String
) throws -> PluginManifest {
    guard isValidPluginID(manifest.id) else { throw PluginInstallError.unsafeId }

    if let api = manifest.apiVersion {
        guard api <= supportedPluginApiVersion else {
            throw PluginInstallError.unsupportedApi(api)
        }
    }
    guard comparePluginVersions(hostVersion, manifest.minHostVersion) != .orderedAscending else {
        throw PluginInstallError.hostTooOld(required: manifest.minHostVersion)
    }
    if manifest.kind == .extension {
        guard let api = manifest.apiVersion, api >= 3 else {
            throw PluginInstallError.extensionRequiresApi3
        }
    }

    let entry = try normalizePluginPath(manifest.entry)
    guard availableFiles.contains(entry) else {
        throw PluginInstallError.missingEntry(manifest.entry)
    }

    if let startUrl = manifest.startUrl, let url = URL(string: startUrl), let host = url.host {
        let allowed = manifest.allowedHosts.contains {
            host.caseInsensitiveCompare($0) == .orderedSame
                || host.lowercased().hasSuffix("." + $0.lowercased())
        }
        guard allowed else { throw PluginInstallError.hostOutsideAllowedHosts(host) }
    }

    var validated = manifest
    validated.entry = entry
    return validated
}

/// SHA-256 of each file, as lowercase hex.
public func pluginChecksums(_ files: [String: Data]) -> [String: String] {
    files.reduce(into: [String: String]()) { result, pair in
        result[pair.key] = SHA256.hash(data: pair.value)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// Verify every non-metadata file is covered and matches its checksum.
public func verifyPluginChecksums(
    files: [String: Data],
    declared: [String: String],
    metadataFiles: Set<String> = ["checksums.json", "signature.json"]
) throws {
    for (path, data) in files where !metadataFiles.contains(path) {
        guard let expected = declared[path] else {
            throw PluginInstallError.checksumMismatch(path)
        }
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
            throw PluginInstallError.checksumMismatch(path)
        }
    }
}
