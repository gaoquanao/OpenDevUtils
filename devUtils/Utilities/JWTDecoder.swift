import Foundation

/// Pure JWT parsing logic, extracted from `JWTDebuggerTool` so it can be unit
/// tested without SwiftUI.
enum JWTDecoder {

    /// What went wrong while decoding a token. The view maps these to
    /// localized messages; keeping them structured makes them testable.
    enum Issue: Equatable {
        case malformed        // fewer than 2 dot-separated parts
        case invalidHeader    // part 0 is not base64url-encoded JSON
        case invalidPayload   // part 1 is not base64url-encoded JSON
    }

    struct Decoded: Equatable {
        /// Pretty-printed, key-sorted header JSON (empty if that part failed).
        var headerJSON = ""
        /// Pretty-printed, key-sorted payload JSON (empty if that part failed).
        var payloadJSON = ""
        /// Raw third part of the token, if present.
        var signature = ""
        /// Human-readable `exp` / `iat` notes, one per line.
        var claimsNote = ""
        var issues: [Issue] = []

        var hasIssues: Bool { !issues.isEmpty }
    }

    /// Shared timestamp formatting for claim notes. POSIX locale keeps the
    /// output deterministic regardless of the user's calendar/region settings.
    static let claimDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func decode(_ rawToken: String) -> Decoded {
        var result = Decoded()

        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return result }

        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else {
            result.issues.append(.malformed)
            return result
        }

        // Header
        if let headerData = base64URLDecode(parts[0]),
           let json = try? JSONSerialization.jsonObject(with: headerData),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            result.headerJSON = String(data: prettyData, encoding: .utf8) ?? ""
        } else {
            result.issues.append(.invalidHeader)
        }

        // Payload
        if let payloadData = base64URLDecode(parts[1]),
           let json = try? JSONSerialization.jsonObject(with: payloadData),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            // Keep payloadJSON as pure JSON so Copy produces valid JSON;
            // human-friendly claim notes are shown separately.
            result.payloadJSON = String(data: prettyData, encoding: .utf8) ?? ""

            if let dict = json as? [String: Any] {
                var notes: [String] = []
                if let exp = dict["exp"] as? TimeInterval {
                    notes.append("exp: \(claimDateFormatter.string(from: Date(timeIntervalSince1970: exp)))")
                }
                if let iat = dict["iat"] as? TimeInterval {
                    notes.append("iat: \(claimDateFormatter.string(from: Date(timeIntervalSince1970: iat)))")
                }
                result.claimsNote = notes.joined(separator: "\n")
            }
        } else {
            result.issues.append(.invalidPayload)
        }

        // Signature
        if parts.count >= 3 {
            result.signature = parts[2]
        }

        return result
    }

    static func base64URLDecode(_ str: String) -> Data? {
        let cleaned = str.components(separatedBy: .whitespacesAndNewlines).joined()
        guard !cleaned.isEmpty else { return nil }

        var base64 = cleaned
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}
