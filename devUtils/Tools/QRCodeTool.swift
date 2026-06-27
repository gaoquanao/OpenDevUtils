import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeTool: Tool {
    let id = "qrCode"
    let name = "QR Code"
    let icon = "qrcode"
    let category: ToolCategory = .webDev
    
    @State private var input = ""
    @State private var qrImage: NSImage?
    @State private var qrContent: String = ""
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
            Spacer()
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
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(input, forType: .string)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var decodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L(.qrCodeInput)).font(.headline)
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
        guard !input.isEmpty else { qrImage = nil; return }
        
        let context = CIContext()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return }
        filter.setValue(Data(input.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        
        guard let outputImage = filter.outputImage else { return }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }
        qrImage = NSImage(cgImage: cgImage, size: NSSize(width: 200, height: 200))
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
