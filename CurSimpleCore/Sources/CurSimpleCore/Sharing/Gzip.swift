import Compression
import Foundation

/// Minimal gzip (RFC 1952) wrapper around raw DEFLATE.
///
/// The shared codec uses Java's GZIPOutputStream, which emits a gzip container;
/// Foundation's `compressed(using: .zlib)` emits raw DEFLATE, so the header and
/// trailer are built here to stay byte-compatible across platforms.
public enum Gzip {

    public static func compress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let capacity = max(data.count + data.count / 2 + 64, 256)
        var output = Data(count: capacity)

        let written = output.withUnsafeMutableBytes { destination -> Int in
            guard let dst = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return data.withUnsafeBytes { source -> Int in
                guard let src = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_encode_buffer(
                    dst, capacity,
                    src, data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard written > 0, written < capacity else { return nil }
        output.removeSubrange(written..<output.count)

        var gzip = Data([0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF])
        gzip.append(output)
        gzip.append(contentsOf: littleEndian(crc32(data)))
        gzip.append(contentsOf: littleEndian(UInt32(truncatingIfNeeded: data.count)))
        return gzip
    }

    /// Decompress with a hard output limit; nil for malformed input or oversized output.
    public static func decompress(_ data: Data, limit: Int) -> Data? {
        guard data.count > 18,
              data[data.startIndex] == 0x1F,
              data[data.startIndex + 1] == 0x8B,
              data[data.startIndex + 2] == 0x08 else {
            return nil
        }
        let flags = data[data.startIndex + 3]
        var offset = 10
        let start = data.startIndex

        // Optional fields: FEXTRA, FNAME, FCOMMENT, FHCRC.
        if flags & 0x04 != 0 {
            guard offset + 2 <= data.count else { return nil }
            let extraLength = Int(data[start + offset]) | (Int(data[start + offset + 1]) << 8)
            offset += 2 + extraLength
        }
        if flags & 0x08 != 0 {
            while offset < data.count, data[start + offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 {
            while offset < data.count, data[start + offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 {
            offset += 2
        }

        let deflateEnd = data.count - 8
        guard offset < deflateEnd else { return nil }
        let deflateData = data.subdata(in: (start + offset)..<(start + deflateEnd))

        var capacity = min(max(deflateData.count * 4, 4096), limit)
        while capacity <= limit {
            var output = Data(count: capacity)
            let written = output.withUnsafeMutableBytes { destination -> Int in
                guard let dst = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return deflateData.withUnsafeBytes { source -> Int in
                    guard let src = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(
                        dst, capacity,
                        src, deflateData.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }
            if written > 0, written < capacity {
                output.removeSubrange(written..<output.count)

                // Validate the trailer when it is present and readable.
                let expectedSize = Int(readLittleEndian(data, at: data.count - 4))
                if expectedSize != 0, expectedSize != output.count {
                    return nil
                }
                return output
            }
            if capacity == limit { return nil }
            capacity = min(capacity * 2, limit)
        }
        return nil
    }

    private static func readLittleEndian(_ data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        guard start + 4 <= data.endIndex else { return 0 }
        return UInt32(data[start])
            | (UInt32(data[start + 1]) << 8)
            | (UInt32(data[start + 2]) << 16)
            | (UInt32(data[start + 3]) << 24)
    }

    private static func littleEndian(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF),
        ]
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? (0xEDB88320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    public static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
