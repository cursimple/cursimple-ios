import Compression
import Foundation

/// Minimal read-only ZIP reader for plugin bundles.
///
/// Supports stored and DEFLATE entries through the central directory, rejects
/// encryption, ZIP64 and unsafe paths, and bounds both per-entry and total size.
public enum ZipArchive {

    public enum ReadError: Error, Equatable, Sendable {
        case notZip
        case unsupported(String)
        case unsafePath(String)
        case tooLarge
        case corrupt(String)
    }

    public struct Entry: Sendable {
        public let path: String
        public let data: Data
    }

    public static func read(
        _ archive: Data,
        maxEntryBytes: Int = 8 * 1024 * 1024,
        maxTotalBytes: Int = 32 * 1024 * 1024
    ) throws -> [Entry] {
        let bytes = [UInt8](archive)
        guard bytes.count > 22 else { throw ReadError.notZip }

        // Locate the end-of-central-directory record from the tail.
        guard let eocd = findEOCD(bytes) else { throw ReadError.notZip }
        let entryCount = Int(readUInt16(bytes, eocd + 10))
        let centralOffset = Int(readUInt32(bytes, eocd + 16))
        guard entryCount >= 0, centralOffset >= 0, centralOffset < bytes.count else {
            throw ReadError.corrupt("central directory")
        }

        var entries: [Entry] = []
        var cursor = centralOffset
        var total = 0

        for _ in 0..<entryCount {
            guard cursor + 46 <= bytes.count, readUInt32(bytes, cursor) == 0x02014b50 else {
                throw ReadError.corrupt("central header")
            }
            let flags = readUInt16(bytes, cursor + 8)
            let method = readUInt16(bytes, cursor + 10)
            let compressedSize = Int(readUInt32(bytes, cursor + 20))
            let uncompressedSize = Int(readUInt32(bytes, cursor + 24))
            let nameLength = Int(readUInt16(bytes, cursor + 28))
            let extraLength = Int(readUInt16(bytes, cursor + 30))
            let commentLength = Int(readUInt16(bytes, cursor + 32))
            let localOffset = Int(readUInt32(bytes, cursor + 42))

            guard cursor + 46 + nameLength <= bytes.count else { throw ReadError.corrupt("name") }
            let nameData = Data(bytes[(cursor + 46)..<(cursor + 46 + nameLength)])
            let rawPath = String(data: nameData, encoding: .utf8) ?? ""

            if flags & 0x1 != 0 { throw ReadError.unsupported("encrypted") }
            if compressedSize == 0xFFFF_FFFF || uncompressedSize == 0xFFFF_FFFF {
                throw ReadError.unsupported("zip64")
            }
            guard uncompressedSize <= maxEntryBytes, total + uncompressedSize <= maxTotalBytes else {
                throw ReadError.tooLarge
            }

            // Directories and macOS metadata are skipped.
            if rawPath.hasSuffix("/") || rawPath.hasPrefix("__MACOSX/") || rawPath == ".DS_Store" {
                cursor += 46 + nameLength + extraLength + commentLength
                continue
            }

            let path = try normalizePluginPath(rawPath)

            guard localOffset + 30 <= bytes.count, readUInt32(bytes, localOffset) == 0x04034b50 else {
                throw ReadError.corrupt("local header")
            }
            let localNameLength = Int(readUInt16(bytes, localOffset + 26))
            let localExtraLength = Int(readUInt16(bytes, localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            guard dataStart + compressedSize <= bytes.count else {
                throw ReadError.corrupt("entry data")
            }
            let raw = Data(bytes[dataStart..<(dataStart + compressedSize)])

            let data: Data
            switch method {
            case 0:
                data = raw
            case 8:
                guard let inflated = inflate(raw, expected: uncompressedSize) else {
                    throw ReadError.corrupt("deflate")
                }
                data = inflated
            default:
                throw ReadError.unsupported("method \(method)")
            }

            total += data.count
            entries.append(Entry(path: path, data: data))
            cursor += 46 + nameLength + extraLength + commentLength
        }

        return entries
    }

    // MARK: - Helpers

    private static func findEOCD(_ bytes: [UInt8]) -> Int? {
        let minimum = 22
        guard bytes.count >= minimum else { return nil }
        let lowerBound = max(0, bytes.count - 66_000)
        var index = bytes.count - minimum
        while index >= lowerBound {
            if readUInt32(bytes, index) == 0x06054b50 { return index }
            index -= 1
        }
        return nil
    }

    private static func readUInt16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        guard offset + 2 <= bytes.count else { return 0 }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readUInt32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        return UInt32(bytes[offset])
            | (UInt32(bytes[offset + 1]) << 8)
            | (UInt32(bytes[offset + 2]) << 16)
            | (UInt32(bytes[offset + 3]) << 24)
    }

    /// Raw DEFLATE (no zlib header), matching what ZIP method 8 stores.
    private static func inflate(_ data: Data, expected: Int) -> Data? {
        guard !data.isEmpty, expected >= 0 else { return nil }
        var capacity = max(expected, 1024)
        for _ in 0..<8 {
            var output = Data(count: capacity)
            let written = output.withUnsafeMutableBytes { destination -> Int in
                guard let dst = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return data.withUnsafeBytes { source -> Int in
                    guard let src = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(
                        dst, capacity,
                        src, data.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }
            if written > 0, written <= capacity {
                output.removeSubrange(written..<output.count)
                if expected == 0 || output.count == expected {
                    return output
                }
                if output.count < expected {
                    capacity = min(capacity * 2, max(expected, capacity * 2))
                    continue
                }
                return output
            }
            capacity *= 2
        }
        return nil
    }
}
