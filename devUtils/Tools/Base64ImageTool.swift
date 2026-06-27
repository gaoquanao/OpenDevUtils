import SwiftUI

struct Base64ImageTool: Tool {
    let id = "base64Image"
    let name = "Base64 Image"
    let icon = "photo"
    let category: ToolCategory = .encoding
    
    @State private var base64Text = ""
    @State private var image: NSImage?
    @State private var errorMessage: String?
    @State private var imageInfo = ""
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
            Text(L(.base64Image))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                base64Text = NSPasteboard.general.string(forType: .string) ?? ""
                decodeImage()
            }
            Button(L(.clear)) {
                base64Text = ""
                image = nil
                imageInfo = ""
                errorMessage = nil
            }
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.base64Input)).font(.headline)
                Spacer()
                if !base64Text.isEmpty {
                    Text("\(base64Text.count) chars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            TextEditor(text: $base64Text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
                .onChange(of: base64Text) { _ in decodeImage() }
            
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
                Text(L(.preview)).font(.headline)
                Spacer()
                if image != nil {
                    Button(L(.saveImage)) {
                        saveImage()
                    }
                    Button(L(.copy)) {
                        if let img = image {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.writeObjects([img])
                        }
                    }
                }
            }
            
            if let img = image {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
                .border(.quaternary, width: 1)
                
                if !imageInfo.isEmpty {
                    Text(imageInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(L(.base64ImageHint))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.leading, 8)
    }
    
    private func decodeImage() {
        errorMessage = nil
        image = nil
        imageInfo = ""
        
        var base64 = base64Text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base64.isEmpty else { return }
        
        // Strip data URI prefix if present
        if let range = base64.range(of: ";base64,") {
            let prefix = String(base64[..<range.lowerBound])
            if prefix.contains("image/png") {
                base64 = String(base64[range.upperBound...])
            } else if prefix.contains("image/jpeg") || prefix.contains("image/jpg") {
                base64 = String(base64[range.upperBound...])
            } else {
                base64 = String(base64[range.upperBound...])
            }
        }
        
        guard let data = Data(base64Encoded: base64) else {
            errorMessage = L(.invalidBase64)
            return
        }
        
        guard let img = NSImage(data: data) else {
            errorMessage = L(.invalidImage)
            return
        }
        
        image = img
        
        let size = img.size
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        imageInfo = "\(Int(size.width)) x \(Int(size.height)) px  |  \(formatter.string(fromByteCount: Int64(data.count)))"
    }
    
    private func saveImage() {
        guard let img = image else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "image.png"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                guard let tiffData = img.tiffRepresentation,
                      let bitmapRep = NSBitmapImageRep(data: tiffData) else { return }
                
                if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "jpeg" {
                    let jpegData = bitmapRep.representation(using: .jpeg, properties: [:])
                    try? jpegData?.write(to: url)
                } else {
                    let pngData = bitmapRep.representation(using: .png, properties: [:])
                    try? pngData?.write(to: url)
                }
            }
        }
    }
}
