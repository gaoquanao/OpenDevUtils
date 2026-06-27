import SwiftUI

struct SQLFormatterTool: Tool {
    let id = "sqlFormatter"
    let name = "SQL Formatter"
    let icon = "terminal"
    let category: ToolCategory = .encoding
    
    @State private var input = ""
    @State private var output = ""
    @State private var indentSize = 2
    @State private var keywordCase: KeywordCase = .upper
    @ObservedObject private var lang = LanguageManager.shared
    
    enum KeywordCase: String, CaseIterable {
        case upper = "UPPER"
        case lower = "lower"
        case capitalize = "Capitalize"
    }
    
    private let sqlKeywords = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
        "ON", "GROUP", "BY", "ORDER", "HAVING", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
        "DELETE", "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "VIEW", "AS", "DISTINCT",
        "COUNT", "SUM", "AVG", "MIN", "MAX", "IN", "NOT", "NULL", "IS", "BETWEEN", "LIKE",
        "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END", "UNION", "ALL", "LIMIT", "OFFSET",
        "ASC", "DESC", "IF", "WITH", "RECURSIVE", "CROSS", "NATURAL", "FULL", "OVER",
        "PARTITION", "ROW_NUMBER", "RANK", "DENSE_RANK", "LEAD", "LAG", "COALESCE",
        "NULLIF", "CAST", "CONVERT", "TRIM", "UPPER", "LOWER", "SUBSTRING", "CONCAT",
        "CURRENT_DATE", "CURRENT_TIMESTAMP", "NOW", "DATE", "EXTRACT", "ROUND", "FLOOR", "CEIL"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                inputSection
                outputSection
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.sqlFormatter))
                .font(.title2.bold())
            Spacer()
            Picker(L(.keywordCase), selection: $keywordCase) {
                ForEach(KeywordCase.allCases, id: \.self) { Text($0.rawValue) }
            }
            .fixedSize()
            .onChange(of: keywordCase) { _ in format() }
            
            Button(L(.paste)) {
                input = PasteboardHelper.readString()
                format()
            }
            Button(L(.execute)) { format() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.input)).font(.headline)
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
                .onChange(of: input) { _ in format() }
        }
        .padding(.trailing, 8)
    }
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.output)).font(.headline)
                Spacer()
                Button(L(.copy)) {
                    PasteboardHelper.writeString(output)
                }
                .disabled(output.isEmpty)
            }
            TextEditor(text: .constant(output))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
                .textSelection(.enabled)
        }
        .padding(.leading, 8)
    }
    
    private static let maxSQLSize = 5_000_000 // 5MB input limit
    
    /// Single combined keyword regex (compiled once, not per-format call).
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
        return try! NSRegularExpression(pattern: "\\b(?:\(all.joined(separator: "|")))\\b", options: [.caseInsensitive])
    }()
    
    /// Single combined newline-insertion regex (compiled once).
    private static let newlinePattern: NSRegularExpression = {
        let majors = ["SELECT", "FROM", "WHERE", "AND", "OR", "JOIN", "LEFT\\s+JOIN", "RIGHT\\s+JOIN",
                      "INNER\\s+JOIN", "OUTER\\s+JOIN", "CROSS\\s+JOIN", "FULL\\s+JOIN", "ON",
                      "GROUP\\s+BY", "ORDER\\s+BY", "HAVING", "LIMIT", "OFFSET",
                      "INSERT\\s+INTO", "VALUES", "UPDATE", "SET", "DELETE\\s+FROM",
                      "CREATE\\s+TABLE", "ALTER\\s+TABLE", "DROP\\s+TABLE", "UNION", "UNION\\s+ALL",
                      "WITH", "EXCEPT", "INTERSECT"]
        return try! NSRegularExpression(pattern: "(?i)\\s+(\(majors.joined(separator: "|")))\\b")
    }()
    
    private func format() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""
            return
        }
        
        var sql = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Size guard
        guard sql.utf8.count < Self.maxSQLSize else {
            output = "SQL too large (\(sql.utf8.count / 1_000_000)MB), max 5MB"
            return
        }
        
        // Normalize whitespace — single regex pass
        sql = sql.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Apply keyword case — ONE regex pass (was 73 individual passes)
        sql = keywordTransform(sql, regex: Self.keywordPattern, keywordCase: keywordCase)
        
        // Add newlines before major keywords — ONE regex pass (was 26 individual passes)
        sql = Self.newlinePattern.stringByReplacingMatches(in: sql,
            range: NSRange(sql.startIndex..., in: sql),
            withTemplate: "\n$1")
        
        // Indent subqueries
        let lines = sql.components(separatedBy: "\n")
        var result: [String] = []
        var indentLevel = 0
        let indent = String(repeating: " ", count: indentSize)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            let upper = trimmed.uppercased()
            
            if upper.hasPrefix(")") {
                indentLevel = max(0, indentLevel - 1)
            }
            
            result.append(String(repeating: indent, count: indentLevel) + trimmed)
            
            if upper.contains("(") && !upper.hasPrefix(")") {
                indentLevel += 1
            }
        }
        
        output = result.joined(separator: "\n")
    }
    
    /// Apply keyword case transformation in a single regex pass.
    private func keywordTransform(_ text: String, regex: NSRegularExpression, keywordCase: KeywordCase) -> String {
        let nsString = text as NSString
        let nsRange = NSRange(location: 0, length: nsString.length)
        var result = ""
        var lastEnd = 0
        
        regex.enumerateMatches(in: text, range: nsRange) { match, _, _ in
            guard let m = match else { return }
            // Append text before this match
            if m.range.location > lastEnd {
                result += nsString.substring(with: NSRange(location: lastEnd, length: m.range.location - lastEnd))
            }
            // Apply case transform to the matched keyword
            let matched = nsString.substring(with: m.range)
            switch keywordCase {
            case .upper: result += matched.uppercased()
            case .lower: result += matched.lowercased()
            case .capitalize:
                if let first = matched.first {
                    result += String(first).uppercased() + matched.dropFirst().lowercased()
                }
            }
            lastEnd = m.range.location + m.range.length
        }
        // Append remaining text after last match
        if lastEnd < nsString.length {
            result += nsString.substring(from: lastEnd)
        }
        return result
    }
}
