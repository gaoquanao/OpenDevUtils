import SwiftUI
import WebKit

struct HTMLPreviewTool: Tool {
    let id = "htmlPreview"
    let name = "HTML Preview"
    let icon = "globe"
    let category: ToolCategory = .encoding
    
    @State private var htmlContent = ""
    @State private var refreshID = UUID()
    @ObservedObject private var lang = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                inputSection
                previewSection
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.htmlPreview))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                htmlContent = NSPasteboard.general.string(forType: .string) ?? ""
                refreshID = UUID()
            }
            Button(L(.refresh)) { refreshID = UUID() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.htmlInput)).font(.headline)
            TextEditor(text: $htmlContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
        }
        .padding(.trailing, 8)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.preview)).font(.headline)
                Spacer()
            }
            HTMLWebView(html: htmlContent, id: refreshID)
                .border(.quaternary, width: 1)
        }
        .padding(.leading, 8)
    }
}

struct HTMLWebView: NSViewRepresentable {
    let html: String
    let id: UUID
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
