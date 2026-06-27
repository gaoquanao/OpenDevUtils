import SwiftUI

struct URLTool: Tool {
    let id = "urlCodec"
    let name = "URL Encode/Decode"
    let icon = "link"
    let category: ToolCategory = .encoding
    
    @State private var input = ""
    @State private var output = ""
    @State private var mode: Mode = .encode
    @State private var encodingType: EncodingType = .component
    @ObservedObject private var lang = LanguageManager.shared
    
    enum Mode: String, CaseIterable {
        case encode
        case decode
    }
    
    enum EncodingType: String, CaseIterable {
        case component
        case full
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Text(L(.mode) + ":").font(.headline)
                    Picker("", selection: $mode) {
                        Text(L(.encode)).tag(Mode.encode)
                        Text(L(.decode)).tag(Mode.decode)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .onChange(of: mode) { _ in process() }
                    
                    Spacer().frame(width: 24)
                    
                    Text(L(.type) + ":").font(.headline)
                    Picker("", selection: $encodingType) {
                        Text(L(.urlComponent)).tag(EncodingType.component)
                        Text(L(.fullUrl)).tag(EncodingType.full)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .onChange(of: encodingType) { _ in process() }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                
                Divider()
                
                VStack(spacing: 16) {
                    inputSection
                    outputSection
                    Spacer(minLength: 0)
                }
                .padding(.top, 12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.urlEncodeDecode))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                input = NSPasteboard.general.string(forType: .string) ?? ""
                process()
            }
            Button(L(.clear)) {
                input = ""
                output = ""
            }
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
                .frame(minHeight: 80, maxHeight: .infinity)
                .onChange(of: input) { _ in process() }
        }
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
                .frame(minHeight: 80, maxHeight: .infinity)
                .textSelection(.enabled)
        }
    }
    
    private func process() {
        guard !input.isEmpty else { output = ""; return }
        
        switch mode {
        case .encode:
            output = encode(input)
        case .decode:
            output = decode(input)
        }
    }
    
    private func encode(_ str: String) -> String {
        switch encodingType {
        case .component:
            return str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? str
        case .full:
            guard let url = URL(string: str) else { return str }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let encodedPath = components?.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? components?.path ?? ""
            components?.path = encodedPath
            return components?.url?.absoluteString ?? str
        }
    }
    
    private func decode(_ str: String) -> String {
        return str.removingPercentEncoding ?? str
    }
}
