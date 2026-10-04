import Foundation

struct Base64Codec {

    static let maxInputBytes = 5_000_000

    enum Failure: Equatable, Error {
        case tooLarge(actual: Int, limit: Int)
        case invalidData
        case notUTF8

        var message: String {
            switch self {
            case .tooLarge(let actual, let limit):
                return L(.inputTooLarge, actual / 1_000_000, limit / 1_000_000)
            case .invalidData:
                return L(.invalidBase64)
            case .notUTF8:
                return L(.base64NotText)
            }
        }
    }

    /// Encode/decode entry point for the Base64 tool.
    static func process(_ input: String, encode: Bool,
                        limit: Int = maxInputBytes) -> Result<String, Failure> {
        let bytes = input.utf8.count
        if bytes >= limit {
            return .failure(.tooLarge(actual: bytes, limit: limit))
        }
        return encode ? .success(encodeBase64(input)) : decode(input)
    }

    static func encodeBase64(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    /// Accepts standard and URL-safe Base64, tolerating whitespace/line breaks
    /// (line-wrapped Base64 is what users typically paste).
    static func decode(_ text: String) -> Result<String, Failure> {
        var cleaned = text.components(separatedBy: .whitespacesAndNewlines).joined()
        guard !cleaned.isEmpty else { return .success("") }
        cleaned = cleaned
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = cleaned.count % 4
        if remainder > 0 {
            cleaned += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: cleaned) else {
            return .failure(.invalidData)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(.notUTF8)
        }
        return .success(text)
    }
}
