import SwiftUI

struct JSONEditorTool: Tool {
    let id = "jsonEditor"
    let name = "JSON Editor"
    let icon = "doc.text.fill"
    let category: ToolCategory = .json
    
    @State private var input = ""
    @State private var output = ""
    @State private var errorMessage: String?
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
            Button(L(.paste)) {
                input = NSPasteboard.general.string(forType: .string) ?? ""
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
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
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
    
    private func prettyPrintJSON() {
        errorMessage = nil
        guard let data = input.data(using: .utf8) else {
            errorMessage = L(.invalidJSON); return
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            output = String(data: prettyData, encoding: .utf8) ?? ""
        } catch {
            errorMessage = "\(L(.invalidJSON)): \(error.localizedDescription)"
            output = ""
        }
    }
    
    private func minifyJSON() {
        errorMessage = nil
        guard let data = input.data(using: .utf8) else {
            errorMessage = L(.invalidJSON); return
        }
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            let minifiedData = try JSONSerialization.data(withJSONObject: json, options: [])
            output = String(data: minifiedData, encoding: .utf8) ?? ""
        } catch {
            errorMessage = "\(L(.invalidJSON)): \(error.localizedDescription)"
            output = ""
        }
    }
}
