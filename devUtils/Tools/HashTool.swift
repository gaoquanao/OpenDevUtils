import SwiftUI
import CryptoKit

struct HashTool: Tool {
    let id = "hash"
    let name = "Hash"
    let icon = "number"
    let category: ToolCategory = .encoding
    
    @State private var input = ""
    @State private var outputMD5 = ""
    @State private var outputSHA1 = ""
    @State private var outputSHA256 = ""
    @State private var outputSHA512 = ""
    @State private var isUpper = false
    @State private var debounceTask: DispatchWorkItem?
    @ObservedObject private var lang = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                inputSection
                optionsSection
                resultsSection
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.hashGenerator))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                input = PasteboardHelper.readString()
                computeHashes()
            }
            Button(L(.clear)) {
                input = ""
                outputMD5 = ""
                outputSHA1 = ""
                outputSHA256 = ""
                outputSHA512 = ""
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
                .onChange(of: input) { _ in
                    debounceCompute()
                }
        }
    }
    
    private var optionsSection: some View {
        HStack {
            Toggle(L(.uppercase), isOn: $isUpper)
                .toggleStyle(.checkbox)
                .onChange(of: isUpper) { _ in debounceCompute() }
            Spacer()
        }
    }
    
    private var resultsSection: some View {
        VStack(spacing: 8) {
            hashRow(label: "MD5", value: outputMD5)
            hashRow(label: "SHA1", value: outputSHA1)
            hashRow(label: "SHA256", value: outputSHA256)
            hashRow(label: "SHA512", value: outputSHA512)
        }
    }
    
    private func hashRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.body, design: .monospaced).bold())
                .frame(width: 60, alignment: .trailing)
            
            Text(value.isEmpty ? "—" : value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(value.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .lineLimit(1)
            
            Spacer()
            
            Button {
                PasteboardHelper.writeString(value)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .disabled(value.isEmpty)
            .help(L(.copy))
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private static let maxHashSize = 10_000_000 // 10MB input limit
    
    /// Debounce: delay heavy computation while user is still typing.
    private func debounceCompute() {
        debounceTask?.cancel()
        let task = DispatchWorkItem { [self] in computeHashes() }
        debounceTask = task
        // Debounce 300ms for inputs > 100KB; immediate for smaller
        if input.utf8.count > 100_000 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
        } else {
            computeHashes()
        }
    }
    
    private func computeHashes() {
        guard let data = input.data(using: .utf8) else {
            clearHashes()
            return
        }
        guard data.count < Self.maxHashSize else {
            clearHashes()
            outputMD5 = "Input too large (\(data.count / 1_000_000)MB), max 10MB"
            return
        }
        
        outputMD5 = format(md5(data))
        outputSHA1 = format(sha1(data))
        outputSHA256 = format(sha256(data))
        outputSHA512 = format(sha512(data))
    }
    
    private func clearHashes() {
        outputMD5 = ""; outputSHA1 = ""; outputSHA256 = ""; outputSHA512 = ""
    }
    
    private func md5(_ data: Data) -> [UInt8] {
        let digest = Insecure.MD5.hash(data: data)
        return Array(digest)
    }
    
    private func sha1(_ data: Data) -> [UInt8] {
        let digest = Insecure.SHA1.hash(data: data)
        return Array(digest)
    }
    
    private func sha256(_ data: Data) -> [UInt8] {
        let digest = SHA256.hash(data: data)
        return Array(digest)
    }
    
    private func sha512(_ data: Data) -> [UInt8] {
        let digest = SHA512.hash(data: data)
        return Array(digest)
    }
    
    private func format(_ bytes: [UInt8]) -> String {
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return isUpper ? hex.uppercased() : hex
    }
}
