import SwiftUI

struct TextDifferTool: Tool {
    let id = "textDiff"
    let name = "Text Diff"
    let icon = "doc.on.doc"
    let category: ToolCategory = .text
    
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var diffResult: [DiffLine] = []
    @State private var ignoreCase = false
    @State private var ignoreWhitespace = false
    @ObservedObject private var lang = LanguageManager.shared
    
    private static let maxDiffLines = 100_000 // prevent OOM
    
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
            Button(L(.paste)) { leftText = PasteboardHelper.readString() }
            Button(L(.paste)) { rightText = PasteboardHelper.readString() }
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
    
    /// Compute a proper LCS-based diff (Myers-like) instead of naive line-by-line comparison.
    private func computeDiff() {
        let leftLines = leftText.components(separatedBy: "\n")
        let rightLines = rightText.components(separatedBy: "\n")
        
        // Size guard
        let totalLines = leftLines.count + rightLines.count
        guard totalLines < Self.maxDiffLines else {
            diffResult = [DiffLine(lineNumber: 0, text: "Too many lines (\(totalLines/1000)k), max \(Self.maxDiffLines/1000)k", type: .added)]
            return
        }
        
        let process: (String) -> String = { s in
            var result = s
            if ignoreCase { result = result.lowercased() }
            if ignoreWhitespace {
                result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            }
            return result
        }
        
        let leftProc = leftLines.map(process)
        let rightProc = rightLines.map(process)
        
        // Compute LCS table
        let m = leftProc.count
        let n = rightProc.count
        
        // Use two rows for O(min(m,n)) memory
        var prev = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            var curr = [Int](repeating: 0, count: n + 1)
            for j in 1...n {
                if leftProc[i-1] == rightProc[j-1] {
                    curr[j] = prev[j-1] + 1
                } else {
                    curr[j] = max(prev[j], curr[j-1])
                }
            }
            prev = curr
        }
        
        // Backtrack to build diff
        var result: [DiffLine] = []
        var i = m
        var j = n
        var lineNum = 1
        
        // Collect operations in reverse
        var ops: [(text: String, type: DiffType)] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && leftProc[i-1] == rightProc[j-1] {
                ops.append((leftLines[i-1], .unchanged))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || prev[j] < prev[j-1]) {
                ops.append((rightLines[j-1], .added))
                j -= 1
            } else if i > 0 {
                ops.append((leftLines[i-1], .removed))
                i -= 1
            }
        }
        
        // Reverse to correct order
        for op in ops.reversed() {
            result.append(DiffLine(lineNumber: lineNum, text: op.text, type: op.type))
            lineNum += 1
        }
        
        diffResult = result
    }
}
