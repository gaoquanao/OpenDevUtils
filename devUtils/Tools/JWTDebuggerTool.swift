import SwiftUI

struct JWTDebuggerTool: Tool {
    let id = "jwtDebugger"
    let name = "JWT Debugger"
    let icon = "key"
    let category: ToolCategory = .webDev
    
    @State private var jwtToken = ""
    @State private var headerJSON = ""
    @State private var payloadJSON = ""
    @State private var signature = ""
    @State private var errorMessage: String?
    @ObservedObject private var lang = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                inputSection
                if !headerJSON.isEmpty {
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
                jwtToken = NSPasteboard.general.string(forType: .string) ?? ""
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
                    Text("Header").font(.headline)
                    Spacer()
                    Button(L(.copy)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(headerJSON, forType: .string)
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
                    Text("Payload").font(.headline)
                    Spacer()
                    Button(L(.copy)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(payloadJSON, forType: .string)
                    }
                }
                TextEditor(text: .constant(payloadJSON))
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.visible)
                    .border(.quaternary, width: 1)
                    .frame(minHeight: 120)
                    .textSelection(.enabled)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L(.signature)).font(.headline)
                    Spacer()
                    Button(L(.copy)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(signature, forType: .string)
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
        
        let token = jwtToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        
        let parts = token.components(separatedBy: ".")
        guard parts.count >= 2 else {
            errorMessage = L(.invalidJWT)
            return
        }
        
        // Decode header
        if let headerData = base64URLDecode(parts[0]),
           let json = try? JSONSerialization.jsonObject(with: headerData),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            headerJSON = String(data: prettyData, encoding: .utf8) ?? ""
        } else {
            errorMessage = L(.invalidJWT)
        }
        
        // Decode payload
        if let payloadData = base64URLDecode(parts[1]),
           let json = try? JSONSerialization.jsonObject(with: payloadData),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            payloadJSON = String(data: prettyData, encoding: .utf8) ?? ""
            
            // Extract expiration
            if let dict = json as? [String: Any] {
                var displayJSON = payloadJSON
                if let exp = dict["exp"] as? TimeInterval {
                    let date = Date(timeIntervalSince1970: exp)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    displayJSON += "\n\n// exp: \(formatter.string(from: date))"
                }
                if let iat = dict["iat"] as? TimeInterval {
                    let date = Date(timeIntervalSince1970: iat)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    displayJSON += "\n// iat: \(formatter.string(from: date))"
                }
                payloadJSON = displayJSON
            }
        } else {
            errorMessage = L(.invalidJWT)
        }
        
        // Signature
        if parts.count >= 3 {
            signature = parts[2]
        }
    }
    
    private func base64URLDecode(_ str: String) -> Data? {
        var base64 = str
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        return Data(base64Encoded: base64)
    }
}
