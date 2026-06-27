import SwiftUI

struct BatchTextTool: Tool {
    let id = "batchText"
    let name = "Batch Text"
    let icon = "text.badge.checkmark"
    let category: ToolCategory = .text
    
    @State private var input = ""
    @State private var output = ""
    @State private var prefix = ""
    @State private var suffix = ""
    @State private var find = ""
    @State private var replace = ""
    @State private var removeDuplicates = false
    @State private var sortLines = false
    @State private var removeEmptyLines = false
    @State private var trimWhitespace = false
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
            Text(L(.batchText))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                input = PasteboardHelper.readString()
            }
            Button(L(.clear)) {
                input = ""
                output = ""
                prefix = ""
                suffix = ""
                find = ""
                replace = ""
            }
            Button(L(.execute)) { process() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L(.input)).font(.headline)
                Spacer()
                let lines = input.components(separatedBy: "\n").filter { !$0.isEmpty }.count
                Text("\(lines) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
            
            Spacer(minLength: 0)
        }
        .padding(.trailing, 8)
    }
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L(.output)).font(.headline)
                Spacer()
                let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }.count
                Text("\(lines) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(L(.copy)) {
                    PasteboardHelper.writeString(output)
                }
                .disabled(output.isEmpty)
            }
            .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                processingOptions
                prefixSuffixSection
                replaceSection
            }
            .padding(.bottom, 12)
            
            TextEditor(text: .constant(output))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
                .textSelection(.enabled)
            
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
    }
    
    private var processingOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.options)).font(.headline)
            HStack(spacing: 16) {
                Toggle(L(.removeDuplicates), isOn: $removeDuplicates)
                    .toggleStyle(.checkbox)
                Toggle(L(.sortLines), isOn: $sortLines)
                    .toggleStyle(.checkbox)
                Toggle(L(.removeEmptyLines), isOn: $removeEmptyLines)
                    .toggleStyle(.checkbox)
                Toggle(L(.trimWhitespace), isOn: $trimWhitespace)
                    .toggleStyle(.checkbox)
                Spacer()
            }
        }
    }
    
    private var prefixSuffixSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.prefixSuffix)).font(.headline)
            HStack(spacing: 12) {
                TextField(L(.prefixPlaceholder), text: $prefix)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                TextField(L(.suffixPlaceholder), text: $suffix)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var replaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.batchReplace)).font(.headline)
            HStack(spacing: 12) {
                TextField(L(.findPlaceholder), text: $find)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                TextField(L(.replacePlaceholder), text: $replace)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private static let maxBatchSize = 500_000 // 500K lines max
    
    private func process() {
        let rawLines = input.components(separatedBy: "\n")
        
        // Size guard
        guard rawLines.count < Self.maxBatchSize else {
            output = "Too many lines (\(rawLines.count / 1000)K), max \(Self.maxBatchSize / 1000)K"
            return
        }
        
        var lines = rawLines
        
        // Trim whitespace
        if trimWhitespace {
            lines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        // Remove empty lines
        if removeEmptyLines {
            lines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        
        // Batch replace
        if !find.isEmpty {
            lines = lines.map { $0.replacingOccurrences(of: find, with: replace) }
        }
        
        // Add prefix and suffix
        if !prefix.isEmpty || !suffix.isEmpty {
            lines = lines.map { prefix + $0 + suffix }
        }
        
        // Remove duplicates
        if removeDuplicates {
            var seen = Set<String>()
            lines = lines.filter { seen.insert($0).inserted }
        }
        
        // Sort
        if sortLines {
            lines.sort()
        }
        
        output = lines.joined(separator: "\n")
    }
}
