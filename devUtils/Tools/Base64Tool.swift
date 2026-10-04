import SwiftUI

struct Base64Tool: Tool {
    let id = "base64"
    let name = "Base64"
    let icon = "lock.fill"
    let category: ToolCategory = .encoding
    
    @State private var input = ""
    @State private var output = ""
    @State private var isEncoding = true
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
            Text(L(.base64Title))
                .font(.title2.bold())
            
            Spacer()
            
            Picker("", selection: $isEncoding) {
                Text(L(.encode)).tag(true)
                Text(L(.decode)).tag(false)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.input))
                    .font(.headline)
                Spacer()
                Button(L(.paste)) {
                    input = PasteboardHelper.readString()
                }
            }
            
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
                .onChange(of: input) { _ in process() }
                .onChange(of: isEncoding) { _ in process() }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding(.trailing, 8)
    }
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.output))
                    .font(.headline)
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
    
    /// The tool previously never wrote to `output`, so it did nothing.
    private func process() {
        errorMessage = nil
        guard !input.isEmpty else {
            output = ""
            return
        }
        switch Base64Codec.process(input, encode: isEncoding) {
        case .success(let text):
            output = text
        case .failure(let failure):
            output = ""
            errorMessage = failure.message
        }
    }
}
