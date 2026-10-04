import Foundation

/// SQL formatting logic extracted from `SQLFormatterTool` so it can be unit
/// tested. Fixes two review findings:
/// - string literals / comments used to be rewritten as keywords and got
///   newlines injected into them (user data corruption)
/// - the indent level only ever grew (any line containing `(` raised it, only
///   lines starting with `)` lowered it)
enum SQLFormatterCore {

    enum KeywordCase: String, CaseIterable {
        case upper = "UPPER"
        case lower = "lower"
        case capitalize = "Capitalize"
    }

    // MARK: - Regexes (compiled once)

    private static let keywordPattern: NSRegularExpression = {
        let all = ["SELECT", "FROM", "WHERE", "AND", "OR", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
                   "ON", "GROUP", "BY", "ORDER", "HAVING", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
                   "DELETE", "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "VIEW", "AS", "DISTINCT",
                   "COUNT", "SUM", "AVG", "MIN", "MAX", "IN", "NOT", "NULL", "IS", "BETWEEN", "LIKE",
                   "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END", "UNION", "ALL", "LIMIT", "OFFSET",
                   "ASC", "DESC", "IF", "WITH", "RECURSIVE", "CROSS", "NATURAL", "FULL", "OVER",
                   "PARTITION", "ROW_NUMBER", "RANK", "DENSE_RANK", "LEAD", "LAG", "COALESCE",
                   "NULLIF", "CAST", "CONVERT", "TRIM", "UPPER", "LOWER", "SUBSTRING", "CONCAT",
                   "CURRENT_DATE", "CURRENT_TIMESTAMP", "NOW", "DATE", "EXTRACT", "ROUND", "FLOOR", "CEIL"]
        return try! NSRegularExpression(pattern: "\\b(?:\(all.joined(separator: "|")))\\b",
                                        options: [.caseInsensitive])
    }()

    private static let newlinePattern: NSRegularExpression = {
        let majors = ["SELECT", "FROM", "WHERE", "AND", "OR", "JOIN", "LEFT\\s+JOIN", "RIGHT\\s+JOIN",
                      "INNER\\s+JOIN", "OUTER\\s+JOIN", "CROSS\\s+JOIN", "FULL\\s+JOIN", "ON",
                      "GROUP\\s+BY", "ORDER\\s+BY", "HAVING", "LIMIT", "OFFSET",
                      "INSERT\\s+INTO", "VALUES", "UPDATE", "SET", "DELETE\\s+FROM",
                      "CREATE\\s+TABLE", "ALTER\\s+TABLE", "DROP\\s+TABLE", "UNION", "UNION\\s+ALL",
                      "WITH", "EXCEPT", "INTERSECT"]
        return try! NSRegularExpression(pattern: "(?i)\\s+(\(majors.joined(separator: "|")))\\b")
    }()

    private static let placeholderPattern = try! NSRegularExpression(pattern: "\u{1}(\\d+)\u{1}")

    // MARK: - Format

    static func format(_ sql: String, indentSize: Int = 2, keywordCase: KeywordCase = .upper) -> String {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Mask literals & comments so nothing below can touch their contents.
        let (masked, segments) = mask(trimmed)

        // Normalize whitespace (placeholders contain none, so contents survive).
        var text = masked.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Keyword case — one regex pass.
        text = applyKeywordCase(text, keywordCase: keywordCase)

        // Newlines before major keywords — one regex pass.
        text = Self.newlinePattern.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "\n$1")

        // Indent by the *net* paren balance of each line (clamped at 0).
        let indentUnit = String(repeating: " ", count: max(indentSize, 0))
        var level = 0
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            let opens = t.filter { $0 == "(" }.count
            let closes = t.filter { $0 == ")" }.count
            level = max(0, level + opens - closes)
            lines.append(String(repeating: indentUnit, count: level) + t)
        }

        return restore(lines.joined(separator: "\n"), segments: segments)
    }

    // MARK: - Literal / comment masking

    /// Replaces string literals, quoted identifiers and comments with
    /// placeholder tokens so later passes cannot modify their contents.
    private static func mask(_ text: String) -> (String, [String]) {
        let chars = Array(text)
        var segments: [String] = []
        var out = ""

        func placeholder(_ segment: String) -> String {
            segments.append(segment)
            return "\u{1}\(segments.count - 1)\u{1}"
        }

        var i = 0
        while i < chars.count {
            let c = chars[i]

            if c == "'" || c == "\"" || c == "`" {
                let quote = c
                var j = i + 1
                var closed = false
                while j < chars.count {
                    if chars[j] == "\\" {
                        j = min(j + 2, chars.count)
                        continue
                    }
                    if chars[j] == quote {
                        if quote == "'" && j + 1 < chars.count && chars[j + 1] == "'" {
                            j += 2 // '' escaping inside single quotes
                            continue
                        }
                        j += 1
                        closed = true
                        break
                    }
                    j += 1
                }
                _ = closed
                out += placeholder(String(chars[i..<j]))
                i = j
                continue
            }

            if c == "-" && i + 1 < chars.count && chars[i + 1] == "-" {
                var j = i
                while j < chars.count && chars[j] != "\n" { j += 1 }
                out += placeholder(String(chars[i..<j]))
                i = j
                continue
            }

            if c == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
                var j = i + 2
                while j + 1 < chars.count && !(chars[j] == "*" && chars[j + 1] == "/") { j += 1 }
                j = min(j + 2, chars.count)
                out += placeholder(String(chars[i..<j]))
                i = j
                continue
            }

            out.append(c)
            i += 1
        }
        return (out, segments)
    }

    private static func restore(_ text: String, segments: [String]) -> String {
        guard !segments.isEmpty else { return text }
        let ns = text as NSString
        var out = ""
        var last = 0
        for m in placeholderPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            }
            let digits = ns.substring(with: NSRange(location: m.range.location + 1,
                                                    length: m.range.length - 2))
            if let idx = Int(digits), segments.indices.contains(idx) {
                out += segments[idx]
            }
            last = m.range.location + m.range.length
        }
        if last < ns.length {
            out += ns.substring(from: last)
        }
        return out
    }

    // MARK: - Keyword case

    private static func applyKeywordCase(_ text: String, keywordCase: KeywordCase) -> String {
        let nsString = text as NSString
        let nsRange = NSRange(location: 0, length: nsString.length)
        var result = ""
        var lastEnd = 0

        keywordPattern.enumerateMatches(in: text, range: nsRange) { match, _, _ in
            guard let m = match else { return }
            if m.range.location > lastEnd {
                result += nsString.substring(with: NSRange(location: lastEnd,
                                                           length: m.range.location - lastEnd))
            }
            let matched = nsString.substring(with: m.range)
            switch keywordCase {
            case .upper:
                result += matched.uppercased()
            case .lower:
                result += matched.lowercased()
            case .capitalize:
                if let first = matched.first {
                    result += String(first).uppercased() + matched.dropFirst().lowercased()
                } else {
                    result += matched
                }
            }
            lastEnd = m.range.location + m.range.length
        }
        if lastEnd < nsString.length {
            result += nsString.substring(from: lastEnd)
        }
        return result
    }
}
