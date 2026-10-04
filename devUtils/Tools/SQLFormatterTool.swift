import SwiftUI

struct SQLFormatterTool: Tool {
    let id = "sqlFormatter"
    let name = "SQL Formatter"
    let icon = "terminal"
    let category: ToolCategory = .encoding
    
    @State private var input = ""
    @State private var output = ""
    @State private var indentSize = 2
    @State private var keywordCase: SQLFormatterCore.KeywordCase = .upper
    @ObservedObject private var lang = LanguageManager.shared
    
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
                ForEach(SQLFormatterCore.KeywordCase.allCases, id: \.self) { Text($0.rawValue) }
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

    private func format() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""
            return
        }

        let sql = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Size guard
        guard sql.utf8.count < Self.maxSQLSize else {
            output = L(.inputTooLarge, sql.utf8.count / 1_000_000, 5)
            return
        }

        output = SQLFormatterCore.format(sql, indentSize: indentSize, keywordCase: keywordCase)
    }
}
