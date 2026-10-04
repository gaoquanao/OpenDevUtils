import Foundation

enum URLEncoderError: LocalizedError {
    case invalidPercentEncoding

    var errorDescription: String? {
        L(.invalidPercentEncoding)
    }
}

/// URL encoding/decoding extracted from `URLTool`. Fixes review findings:
/// - component encoding used `.urlQueryAllowed`, which leaves `& = + ? # /`
///   etc. intact and produces broken query values
/// - full URL encoding only touched the path and could double-encode
/// - decode failures silently returned the input
enum URLEncoder {

    /// Characters that stay unescaped in a URI component (RFC 3986
    /// unreserved set plus a few `encodeURIComponent` extras).
    private static let componentAllowed: Set<Character> = {
        var set = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~!'()*")
        return set
    }()

    /// Everything a URL may contain besides unreserved characters: the
    /// gen-delims / sub-delims that give a URL its structure.
    private static let urlAllowed: Set<Character> = {
        var set = componentAllowed
        set.formUnion(":/?#[]@!$&'()*+,;=%")
        return set
    }()

    // MARK: - Component encoding (encodeURIComponent equivalent)

    static func encodeComponent(_ string: String) -> String {
        var out = ""
        out.reserveCapacity(string.utf8.count)
        for byte in string.utf8 {
            let scalar = Character(UnicodeScalar(byte))
            if componentAllowed.contains(scalar) {
                out.append(scalar)
            } else {
                out.append(String(format: "%%%02X", byte))
            }
        }
        return out
    }

    // MARK: - Full URL encoding

    /// Percent-encodes characters that are not allowed in a URL while
    /// preserving existing (valid) percent-escapes and URL structure.
    static func encodeFullURL(_ string: String) -> String {
        let chars = Array(string)
        var out = ""
        out.reserveCapacity(chars.count)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "%" {
                // Keep a valid %XX escape as-is; escape a bare "%" instead.
                if i + 2 < chars.count,
                   isHex(chars[i + 1]), isHex(chars[i + 2]) {
                    out.append(contentsOf: [chars[i], chars[i + 1], chars[i + 2]])
                    i += 3
                    continue
                }
                out += "%25"
                i += 1
                continue
            }
            if urlAllowed.contains(c) {
                out.append(c)
                i += 1
                continue
            }
            for byte in String(c).utf8 {
                out.append(String(format: "%%%02X", byte))
            }
            i += 1
        }
        return out
    }

    private static func isHex(_ c: Character) -> Bool {
        ("0"..."9").contains(c) || ("a"..."f").contains(c) || ("A"..."F").contains(c)
    }

    // MARK: - Decoding

    /// Decodes percent-escapes, throwing on malformed input instead of
    /// silently passing it through.
    static func decode(_ string: String) throws -> String {
        let bytes = Array(string.utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            if bytes[i] == 0x25 { // "%"
                guard i + 2 < bytes.count,
                      let hi = hexValue(bytes[i + 1]),
                      let lo = hexValue(bytes[i + 2]) else {
                    throw URLEncoderError.invalidPercentEncoding
                }
                out.append(hi << 4 | lo)
                i += 3
                continue
            }
            out.append(bytes[i])
            i += 1
        }
        guard let decoded = String(data: Data(out), encoding: .utf8) else {
            // Valid escapes that don't form UTF-8 (e.g. "%e4%b8") are errors too.
            throw URLEncoderError.invalidPercentEncoding
        }
        return decoded
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39: return byte - 0x30            // 0-9
        case 0x61...0x66: return byte - 0x61 + 10       // a-f
        case 0x41...0x46: return byte - 0x41 + 10       // A-F
        default: return nil
        }
    }
}
