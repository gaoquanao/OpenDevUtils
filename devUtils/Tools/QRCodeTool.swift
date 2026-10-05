import SwiftUI

struct QRCodeTool: Tool {
    let id = "qrCode"
    let name = "QR Code"
    let icon = "qrcode"
    let category: ToolCategory = .webDev
    
    @State private var input = ""
    @State private var qrImage: NSImage?
    @State private var qrContent: String = ""
    @State private var decodedText: String?
    @State private var mode: Mode = .generate
    @State private var errorMessage: String?
    @ObservedObject private var lang = LanguageManager.shared
    
    enum Mode: String, CaseIterable {
        case generate
        case decode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                modePicker
                if mode == .generate {
                    generateSection
                } else {
                    decodeSection
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
            Text(L(.qrCode))
                .font(.title2.bold())
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private var modePicker: some View {
        // Horizontal scrolling protects the labels on narrow panes.
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button {
                        mode = m
                    } label: {
                        Text(m == .generate ? L(.generate) : L(.scanQR))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(mode == m ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            .foregroundColor(mode == m ? .white : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(.input)).font(.headline)
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minHeight: 100)
                .onChange(of: input) { _ in generateQR() }
            
            if let img = qrImage {
                HStack {
                    Spacer()
                    Image(nsImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .border(.quaternary, width: 1)
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    Button(L(.saveImage)) {
                        saveImage(img)
                    }
                    Button(L(.copy)) {
                        PasteboardHelper.writeString(input)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var decodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L(.qrCodeInput)).font(.headline)
                Spacer()
                Button(L(.paste)) { decodeFromClipboard() }
            }
            TextEditor(text: $qrContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minHeight: 100)
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }
    
    private func generateQR() {
        guard !input.isEmpty else {
            qrImage = nil
            return
        }
        guard let cgImage = QRCoder.generate(from: input) else {
            // Clear the stale QR code instead of keeping the previous one.
            qrImage = nil
            return
        }
        qrImage = NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 200))
    }
    
    /// Reads an image from the clipboard and decodes any QR code it contains.
    private func decodeFromClipboard() {
        errorMessage = nil
        let pasteboard = NSPasteboard.general
        let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
        guard let data = data, let image = NSImage(data: data) else {
            errorMessage = L(.clipboardHasNoImage)
            return
        }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let text = QRCoder.decode(cgImage) else {
            errorMessage = L(.noQRCodeFound)
            return
        }
        qrContent = text
    }
    
    private func saveImage(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "qrcode.png"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? pngData.write(to: url)
            }
        }
    }
}
