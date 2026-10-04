import Foundation

/// Extracts detailed error position info from JSON parsing failures.
///
/// `JSONSerialization` reports the failure position as
/// `NSJSONSerializationErrorIndex` — a **UTF-8 byte offset** (verified on
/// macOS: messages read "around line X, column Y" where the column equals the
/// byte offset within the line). Positions are therefore computed from UTF-8
/// bytes so CJK/emoji input reports correct line/column, and offsets pointing
/// exactly at the end of input (truncated JSON) are still located.
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
        let nsError = error as NSError
        let desc = nsError.userInfo[NSDebugDescriptionErrorKey] as? String
            ?? nsError.localizedDescription

        let utf8Count = input.utf8.count

        // 1) Preferred: exact UTF-8 byte index reported by JSONSerialization.
        if let index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int,
           index >= 0, index <= utf8Count {
            return makePosition(byteOffset: index, desc: desc)
        }

        // 2) Modern message without index: "around line X, column Y" where the
        //    column is a byte offset within that line.
        if let regex = try? NSRegularExpression(pattern: #"around line (\d+), column (\d+)"#,
                                                options: .caseInsensitive),
           let match = regex.firstMatch(in: desc, range: NSRange(desc.startIndex..., in: desc)),
           let lineRange = Range(match.range(at: 1), in: desc),
           let columnRange = Range(match.range(at: 2), in: desc),
           let reportedLine = Int(desc[lineRange]),
           let reportedColumn = Int(desc[columnRange]) {
            if let lineStart = byteOffset(ofLine: reportedLine) {
                let offset = min(lineStart + reportedColumn, utf8Count)
                return makePosition(byteOffset: offset, desc: desc)
            }
        }

        // 3) Legacy messages with a bare offset: "around character N",
        //    "character N", "at index N", "offset N" (treated as byte offsets).
        let patterns = [
            "around character (\\d+)",
            "character (\\d+)",
            "at index (\\d+)",
            "offset (\\d+)",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: desc, range: NSRange(desc.startIndex..., in: desc)),
               let range = Range(match.range(at: 1), in: desc),
               let value = Int(desc[range]),
               value >= 0, value <= utf8Count {
                return makePosition(byteOffset: value, desc: desc)
            }
        }
        return nil
    }

    // MARK: - Position computation

    /// Walks the input once (no copies) converting a UTF-8 byte offset into a
    /// 1-based line/column (column counted in Characters of the error line).
    private func makePosition(byteOffset: Int, desc: String) -> ErrorPosition {
        var line = 1
        var column = 1
        var byteIndex = 0

        for character in input {
            if byteIndex >= byteOffset { break }
            let length = character.utf8.count
            if character == "\n" {
                line += 1
                column = 1
            } else if byteIndex + length > byteOffset {
                break // offset points inside this character
            } else {
                column += 1
            }
            byteIndex += length
        }

        let cleanedMessage = cleanMessage(desc)
        return ErrorPosition(
            line: line,
            column: column,
            offset: byteOffset,
            snippet: snippet(fallbackLine: line),
            message: cleanedMessage.isEmpty ? "Invalid JSON" : cleanedMessage
        )
    }

    /// Byte offset where the given 1-based line starts, if it exists.
    private func byteOffset(ofLine requestedLine: Int) -> Int? {
        guard requestedLine >= 1 else { return nil }
        var line = 1
        var byteIndex = 0
        if requestedLine == 1 { return 0 }
        for byte in input.utf8 {
            if byte == 0x0A { // \n
                line += 1
                if line == requestedLine { return byteIndex + 1 }
            }
            byteIndex += 1
        }
        return nil
    }

    /// Context around the error line: up to one line before and the error line.
    private func snippet(fallbackLine: Int) -> String {
        let lines = input.components(separatedBy: "\n")
        guard !lines.isEmpty else { return "" }
        let lineNum = min(max(fallbackLine, 1), lines.count)
        let start = max(0, lineNum - 2)
        let end = min(lines.count, lineNum + 1)
        guard start < end else { return "" }
        return lines[start..<end].enumerated().map { index, line in
            let realLine = start + index + 1
            let marker = realLine == lineNum ? "→ " : "  "
            return "\(marker)\(realLine): \(line)"
        }.joined(separator: "\n")
    }

    private func cleanMessage(_ desc: String) -> String {
        desc
            .replacingOccurrences(of: #" around line \d+, column \d+\.?"#, with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #" around character \d+"#, with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #" around index \d+"#, with: "",
                                  options: .regularExpression)
            .replacingOccurrences(of: #" at line \d+, column \d+"#, with: "",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Attempt JSON parse and return either the parsed object or a detailed error message.
    static func tryParse(jsonString: String) -> (object: Any?, error: String?) {
        guard let data = jsonString.data(using: .utf8) else {
            return (nil, "Failed to convert input to UTF-8 data")
        }

        do {
            // .allowFragments: top-level numbers/strings/bools/null are valid JSON.
            let obj = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            return (obj, nil)
        } catch {
            let locator = JSONErrorLocator(input: jsonString, error: error)
            if let pos = locator.locate() {
                return (nil, "Line \(pos.line), Column \(pos.column): \(pos.message)\n\n\(pos.snippet)")
            }
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
