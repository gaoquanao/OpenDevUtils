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
    
    private static let maxJSONSize = 50_000_000 // 50 MB input limit

    private func prettyPrintJSON() {
        errorMessage = nil
        let utf8Count = input.utf8.count
        guard utf8Count < Self.maxJSONSize else {
            errorMessage = L(.jsonTooLarge, utf8Count / 1_000_000, Self.maxJSONSize / 1_000_000)
            return
        }
        let (json, err) = tryParseJSON(input)
        if let err = err {
            errorMessage = err
            output = ""
            return
        }
        do {
            let prettyData = try JSONSerialization.data(withJSONObject: json!, options: [.prettyPrinted, .sortedKeys])
            output = String(data: prettyData, encoding: .utf8) ?? ""
        } catch {
            errorMessage = "\(L(.invalidJSON)): \(error.localizedDescription)"
            output = ""
        }
    }
    
    private func minifyJSON() {
        errorMessage = nil
        let utf8Count = input.utf8.count
        guard utf8Count < Self.maxJSONSize else {
            errorMessage = L(.jsonTooLarge, utf8Count / 1_000_000, Self.maxJSONSize / 1_000_000)
            return
        }
        let (json, err) = tryParseJSON(input)
        if let err = err {
            errorMessage = err
            output = ""
            return
        }
        do {
            let minifiedData = try JSONSerialization.data(withJSONObject: json!, options: [])
            output = String(data: minifiedData, encoding: .utf8) ?? ""
        } catch {
            errorMessage = "\(L(.invalidJSON)): \(error.localizedDescription)"
            output = ""
        }
    }
}
