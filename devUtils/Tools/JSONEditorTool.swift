import SwiftUI

struct JSONEditorTool: Tool {
    let id = "jsonEditor"
    let name = "JSON Editor"
    let icon = "doc.text.fill"
    let category: ToolCategory = .json
    
    @State private var input = ""
    @State private var output = ""
    @State private var outputPreview = JSONProcessor.Preview(display: "", truncated: false, totalCharacters: 0)
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var requestVersion = 0
    @State private var outputMode: JSONOutputMode = .tree
    @State private var expandAllToken = 0
    @State private var collapseAllToken = 0
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
            Text(L(.jsonEditor))
                .font(.title2.bold())
            Spacer()
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            }
            Button(L(.paste)) {
                input = PasteboardHelper.readString()
                prettyPrintJSON()
            }
            Button(L(.prettyPrint)) { prettyPrintJSON() }
            Button(L(.minify)) { minifyJSON() }
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.input)).font(.headline)
            HighlightedTextEditor(text: $input, language: "JSON")
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
        .padding(.trailing, 8)
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.output)).font(.headline)
                Spacer()
                if !output.isEmpty {
                    outputModePicker
                    if outputMode == .tree {
                        expandCollapseButtons
                    }
                }
                Button(L(.copy)) {
                    PasteboardHelper.writeString(output)
                }
                .disabled(output.isEmpty)
            }
            if outputMode == .tree {
                JSONTreeView(text: output,
                             expandAllToken: expandAllToken,
                             collapseAllToken: collapseAllToken)
                    .border(.quaternary, width: 1)
                    .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
            } else {
                // ScrollView + Text lays out large output far cheaper than a
                // TextEditor (NSTextView), and only the previewed slice is rendered.
                ScrollView {
                    Text(outputPreview.display)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
            }
            if outputPreview.truncated && outputMode == .text {
                Label(L(.outputTruncated, outputPreview.display.count, outputPreview.totalCharacters),
                      systemImage: "scissors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 8)
    }

    private var outputModePicker: some View {
        Picker("", selection: $outputMode) {
            Text(L(.viewModeText)).tag(JSONOutputMode.text)
            Text(L(.viewModeTree)).tag(JSONOutputMode.tree)
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private var expandCollapseButtons: some View {
        HStack(spacing: 4) {
            Button {
                expandAllToken += 1
            } label: {
                Image(systemName: "plus.square")
            }
            .help(L(.expandAll))
            Button {
                collapseAllToken += 1
            } label: {
                Image(systemName: "minus.square")
            }
            .help(L(.collapseAll))
        }
    }
    
    private func prettyPrintJSON() {
        process { JSONProcessor.prettyPrint($0) }
    }
    
    private func minifyJSON() {
        process { JSONProcessor.minify($0) }
    }
    
    /// Parses/serializes off the main thread; stale requests (the user kept
    /// typing or clicked again) are dropped via `requestVersion`.
    private func process(_ work: @escaping (String) -> Result<String, JSONProcessor.Failure>) {
        errorMessage = nil
        output = ""
        outputPreview = JSONProcessor.Preview(display: "", truncated: false, totalCharacters: 0)
        requestVersion += 1
        let version = requestVersion
        let snapshot = input
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work(snapshot)
            DispatchQueue.main.async {
                guard version == requestVersion else { return }
                isProcessing = false
                switch result {
                case .success(let text):
                    output = text
                    outputPreview = JSONProcessor.preview(text)
                    // Pretty print and Minify *are* text formatting — show
                    // their result as text instead of the structured tree.
                    outputMode = .text
                case .failure(let failure):
                    errorMessage = failure.message
                }
            }
        }
    }
}
