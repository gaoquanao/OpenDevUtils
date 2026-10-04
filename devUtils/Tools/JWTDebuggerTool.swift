import SwiftUI

struct JWTDebuggerTool: Tool {
    let id = "jwtDebugger"
    let name = "JWT Debugger"
    let icon = "key"
    let category: ToolCategory = .json
    
    @State private var jwtToken = ""
    @State private var headerJSON = ""
    @State private var payloadJSON = ""
    @State private var signature = ""
    @State private var claimsNote = ""
    @State private var errorMessage: String?
    @ObservedObject private var lang = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                inputSection
                if !headerJSON.isEmpty || !payloadJSON.isEmpty {
                    outputSection
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.jwtDebugger))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                jwtToken = PasteboardHelper.readString()
                decode()
            }
            Button(L(.clear)) {
                jwtToken = ""
                headerJSON = ""
                payloadJSON = ""
                signature = ""
                errorMessage = nil
            }
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.jwtTokenInput)).font(.headline)
            TextEditor(text: $jwtToken)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minHeight: 80)
                .onChange(of: jwtToken) { _ in decode() }
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    private var outputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L(.jwtHeader)).font(.headline)
                    Spacer()
                    Button(L(.copy)) {
                        PasteboardHelper.writeString(headerJSON)
                    }
                }
                TextEditor(text: .constant(headerJSON))
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.visible)
                    .border(.quaternary, width: 1)
                    .frame(minHeight: 120)
                    .textSelection(.enabled)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L(.jwtPayload)).font(.headline)
                    Spacer()
                    Button(L(.copy)) {
                        PasteboardHelper.writeString(payloadJSON)
                    }
                }
                TextEditor(text: .constant(payloadJSON))
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.visible)
                    .border(.quaternary, width: 1)
                    .frame(minHeight: 120)
                    .textSelection(.enabled)
                if !claimsNote.isEmpty {
                    Text(claimsNote)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L(.signature)).font(.headline)
                    Spacer()
                    Button(L(.copy)) {
                        PasteboardHelper.writeString(signature)
                    }
                }
                Text(signature.isEmpty ? "—" : signature)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }
        }
    }
    
    private func decode() {
        errorMessage = nil
        headerJSON = ""
        payloadJSON = ""
        signature = ""
        claimsNote = ""

        guard !jwtToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let decoded = JWTDecoder.decode(jwtToken)
        headerJSON = decoded.headerJSON
        payloadJSON = decoded.payloadJSON
        signature = decoded.signature
        claimsNote = decoded.claimsNote

        errorMessage = decoded.issues.map { issue -> String in
            switch issue {
            case .malformed: return L(.invalidJWT)
            case .invalidHeader: return "\(L(.jwtHeader)): \(L(.invalidJWT))"
            case .invalidPayload: return "\(L(.jwtPayload)): \(L(.invalidJWT))"
            }
        }.joined(separator: "\n")
    }
}
