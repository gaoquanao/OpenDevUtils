import SwiftUI

struct TextDifferTool: Tool {
    let id = "textDiff"
    let name = "Text Diff"
    let icon = "doc.on.doc"
    let category: ToolCategory = .encoding
    
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var diffResult: [DiffLine] = []
    @State private var ignoreCase = false
    @State private var ignoreWhitespace = false
    @ObservedObject private var lang = LanguageManager.shared
    
    struct DiffLine: Identifiable {
        let id = UUID()
        let lineNumber: Int
        let text: String
        let type: DiffType
    }
    
    enum DiffType {
        case added
        case removed
        case unchanged
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                optionsRow
                HSplitView {
                    textArea(title: L(.original), text: $leftText)
                    textArea(title: L(.modified), text: $rightText)
                }
                .frame(minHeight: 150, maxHeight: .infinity)
                diffResultsSection
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.textDiff))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) { leftText = NSPasteboard.general.string(forType: .string) ?? "" }
            Button(L(.paste)) { rightText = NSPasteboard.general.string(forType: .string) ?? "" }
            Button(L(.compare)) { computeDiff() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.bottom, 8)
    }
    
    private var optionsRow: some View {
        HStack {
            Toggle(L(.ignoreCase), isOn: $ignoreCase).toggleStyle(.checkbox)
            Toggle(L(.ignoreWhitespace), isOn: $ignoreWhitespace).toggleStyle(.checkbox)
            Spacer()
        }
    }
    
    private func textArea(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
        }
    }
    
    private var diffResultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.diffResult)).font(.headline)
                Spacer()
                if !diffResult.isEmpty {
                    let added = diffResult.filter { $0.type == .added }.count
                    let removed = diffResult.filter { $0.type == .removed }.count
                    Text("+\(added) -\(removed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if diffResult.isEmpty {
                Text(L(.clickCompareToSeeDifferences))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(diffResult) { line in
                            HStack(spacing: 8) {
                                Text(String(format: "%3d", line.lineNumber))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Circle()
                                    .fill(colorForType(line.type))
                                    .frame(width: 6, height: 6)
                                
                                Text(line.text)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(backgroundForType(line.type))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .border(.quaternary, width: 1)
            }
        }
    }
    
    private func colorForType(_ type: DiffType) -> Color {
        switch type {
        case .added: return .green
        case .removed: return .red
        case .unchanged: return .clear
        }
    }
    
    private func backgroundForType(_ type: DiffType) -> Color {
        switch type {
        case .added: return Color.green.opacity(0.1)
        case .removed: return Color.red.opacity(0.1)
        case .unchanged: return Color.clear
        }
    }
    
    private func computeDiff() {
        let leftLines = leftText.components(separatedBy: "\n")
        let rightLines = rightText.components(separatedBy: "\n")
        
        let process: (String) -> String = { s in
            var result = s
            if ignoreCase { result = result.lowercased() }
            if ignoreWhitespace {
                result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            return result
        }
        
        var result: [DiffLine] = []
        let maxCount = max(leftLines.count, rightLines.count)
        
        var lineNum = 1
        for i in 0..<maxCount {
            let left = i < leftLines.count ? leftLines[i] : nil
            let right = i < rightLines.count ? rightLines[i] : nil
            
            let leftProcessed = left.map(process) ?? ""
            let rightProcessed = right.map(process) ?? ""
            
            if leftProcessed == rightProcessed {
                if let l = left {
                    result.append(DiffLine(lineNumber: lineNum, text: l, type: .unchanged))
                }
            } else {
                if let l = left {
                    result.append(DiffLine(lineNumber: lineNum, text: l, type: .removed))
                }
                if let r = right {
                    result.append(DiffLine(lineNumber: lineNum, text: r, type: .added))
                }
            }
            lineNum += 1
        }
        
        diffResult = result
    }
}
