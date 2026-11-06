import Foundation

public enum ShareCodecError: Error, Equatable, Sendable {
    case notShareData
    case tooLarge
    case malformed
}

/// `CSV1:` + Base64URL(gzip(JSON)); byte-compatible with the shared codec.
public enum ShareCodec {

    public static let maxEncodedCharacters = 6 * 1024 * 1024
    public static let maxDecodedBytes = 4 * 1024 * 1024

    public static func encode(_ payload: ScheduleSharePayload, pretty: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : []
        let raw = try encoder.encode(payload)
        guard let gzipped = Gzip.compress(raw) else {
            throw ShareCodecError.malformed
        }
        return ScheduleSharePayload.magicPrefix + base64URL(gzipped)
    }

    public static func decode(_ text: String) throws -> ScheduleSharePayload {
        let trimmed = text.filter { !$0.isWhitespace }
        guard trimmed.count <= maxEncodedCharacters else {
            throw ShareCodecError.tooLarge
        }
        guard trimmed.hasPrefix(ScheduleSharePayload.magicPrefix) else {
            throw ShareCodecError.notShareData
        }
        let body = String(trimmed.dropFirst(ScheduleSharePayload.magicPrefix.count))
        guard let gzipped = dataFromBase64URL(body) else {
            throw ShareCodecError.notShareData
        }
        guard let raw = Gzip.decompress(gzipped, limit: maxDecodedBytes) else {
            throw ShareCodecError.malformed
        }
        guard let payload = try? JSONDecoder().decode(ScheduleSharePayload.self, from: raw) else {
            throw ShareCodecError.malformed
        }
        guard payload.v == ScheduleSharePayload.currentVersion else {
            throw ShareCodecError.notShareData
        }
        return payload
    }

    // MARK: - Base64URL (padding kept, as the shared encoder keeps it)

    public static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    public static func dataFromBase64URL(_ text: String) -> Data? {
        var normalized = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while normalized.count % 4 != 0 {
            normalized.append("=")
        }
        return Data(base64Encoded: normalized)
    }
}
