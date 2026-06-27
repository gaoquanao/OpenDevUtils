import Foundation

/// Extracts detailed error position info from JSON parsing failures.
/// Converts character offsets from JSONSerialization error descriptions
/// into human-readable line:column + context snippet.
struct JSONErrorLocator {
    let input: String
    let error: Error

    struct ErrorPosition {
        let line: Int
        let column: Int
        let offset: Int
        let snippet: String
        let message: String
    }

    func locate() -> ErrorPosition? {
        // Try to extract character offset from CocoaError's debug description
        let nsError = error as NSError
        let desc = nsError.userInfo[NSDebugDescriptionErrorKey] as? String
            ?? nsError.localizedDescription

        // Pattern: "around character X" or "character X"
        let patterns = [
            "around character (\\d+)",
            "character (\\d+)",
            "at index (\\d+)",
            "offset (\\d+)",
            "column (\\d+)",
        ]

        var offset: Int?
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: desc, range: NSRange(desc.startIndex..., in: desc)),
               let range = Range(match.range(at: 1), in: desc),
               let val = Int(desc[range]) {
                offset = val
                break
            }
        }

        guard let charOffset = offset, charOffset >= 0, charOffset < input.count else {
            return nil
        }

        let lines = input.components(separatedBy: "\n")
        var accumulated = 0
        var lineNum = 0
        var colNum = 0

        for (i, line) in lines.enumerated() {
            let lineLen = line.count + 1 // +1 for \n
            if accumulated + lineLen > charOffset {
                lineNum = i + 1
                colNum = charOffset - accumulated + 1
                break
            }
            accumulated += lineLen
        }

        if lineNum == 0 {
            lineNum = lines.count
            colNum = (lines.last?.count ?? 0)
        }

        // Build context snippet: show the error line ±1
        let snippetLines = lines[max(0, lineNum-2)..<min(lines.count, lineNum+1)]
        let snippet = snippetLines.enumerated().map { (idx, line) -> String in
            let realLine = max(0, lineNum-2) + idx + 1
            let marker = realLine == lineNum ? "→ " : "  "
            return "\(marker)\(realLine): \(line)"
        }.joined(separator: "\n")

        let cleanMessage = desc
            .replacingOccurrences(of: " around character \\d+", with: "", options: .regularExpression)
            .replacingOccurrences(of: " around index \\d+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ErrorPosition(
            line: lineNum,
            column: colNum,
            offset: charOffset,
            snippet: snippet,
            message: cleanMessage.isEmpty ? "Invalid JSON" : cleanMessage
        )
    }

    /// Attempt JSON parse and return either the parsed object or a detailed error message.
    static func tryParse(jsonString: String) -> (object: Any?, error: String?) {
        guard let data = jsonString.data(using: .utf8) else {
            return (nil, "Failed to convert input to UTF-8 data")
        }

        do {
            let obj = try JSONSerialization.jsonObject(with: data)
            return (obj, nil)
        } catch {
            let locator = JSONErrorLocator(input: jsonString, error: error)
            if let pos = locator.locate() {
                return (nil, "Line \(pos.line), Column \(pos.column): \(pos.message)\n\n\(pos.snippet)")
            }
            // Fallback: parse the NSError userInfo for a readable message
            let nsError = error as NSError
            let desc = nsError.userInfo[NSDebugDescriptionErrorKey] as? String
                ?? nsError.localizedDescription
            return (nil, desc)
        }
    }
}

/// Attempt JSON parse with error position info — convenience wrapper.
/// Returns (parsedObject?, errorMessage?) — exactly one is non-nil.
func tryParseJSON(_ jsonString: String) -> (object: Any?, error: String?) {
    JSONErrorLocator.tryParse(jsonString: jsonString)
}
