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
                input = NSPasteboard.general.string(forType: .string) ?? ""
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
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
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
    
    private func format() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""
            return
        }
        
        var sql = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize whitespace
        sql = sql.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Apply keyword case
        for keyword in sqlKeywords {
            let pattern = "\\b\(keyword)\\b"
            let replacement: String
            switch keywordCase {
            case .upper: replacement = keyword.uppercased()
            case .lower: replacement = keyword.lowercased()
            case .capitalize: replacement = keyword.prefix(1).uppercased() + keyword.dropFirst().lowercased()
            }
            sql = sql.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        
        // Add newlines before major keywords
        let majorKeywords = ["SELECT", "FROM", "WHERE", "AND", "OR", "JOIN", "LEFT JOIN", "RIGHT JOIN",
                            "INNER JOIN", "OUTER JOIN", "CROSS JOIN", "FULL JOIN", "ON",
                            "GROUP BY", "ORDER BY", "HAVING", "LIMIT", "OFFSET",
                            "INSERT INTO", "VALUES", "UPDATE", "SET", "DELETE FROM",
                            "CREATE TABLE", "ALTER TABLE", "DROP TABLE", "UNION", "UNION ALL",
                            "WITH", "EXCEPT", "INTERSECT"]
        
        for keyword in majorKeywords {
            let pattern = "(?i)\\s+\(keyword.replacingOccurrences(of: " ", with: "\\s+"))\\b"
            sql = sql.replacingOccurrences(of: pattern, with: "\n\(keywordCase == .upper ? keyword.uppercased() : keywordCase == .lower ? keyword.lowercased() : keyword)", options: .regularExpression)
        }
        
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
}
