import SwiftUI
import WebKit

struct HTMLPreviewTool: Tool {
    let id = "htmlPreview"
    let name = "HTML Preview"
    let icon = "globe"
    let category: ToolCategory = .webDev
    
    @State private var htmlContent = ""
    @State private var previewHTML = ""
    @State private var refreshID = UUID()
    @State private var refreshWork: DispatchWorkItem?
    @ObservedObject private var lang = LanguageManager.shared
    
    private static let maxHTMLSize = 10_000_000 // 10MB
    
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
        .onAppear { scheduleReload(immediate: true) }
    }
    
    private var header: some View {
        HStack {
            Text(L(.htmlPreview))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                htmlContent = PasteboardHelper.readString()
                scheduleReload(immediate: true)
            }
            Button(L(.refresh)) { scheduleReload(immediate: true) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.htmlInput)).font(.headline)
                Spacer()
                if htmlContent.utf8.count >= Self.maxHTMLSize {
                    Text(L(.inputTooLarge, htmlContent.utf8.count / 1_000_000, 10))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            TextEditor(text: $htmlContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .onChange(of: htmlContent) { _ in scheduleReload(immediate: false) }
        }
        .padding(.trailing, 8)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.preview)).font(.headline)
                Spacer()
            }
            HTMLWebView(html: previewHTML, id: refreshID)
                .border(.quaternary, width: 1)
        }
        .padding(.leading, 8)
    }
    
    private var displayHTML: String {
        guard htmlContent.utf8.count < Self.maxHTMLSize else { return "" }
        return htmlContent
    }
    
    /// Debounced reload — reloaded on every keystroke before, which lost the
    /// scroll position and flashed white. The web view receives `previewHTML`,
    /// which only updates after the debounce (or an explicit Refresh).
    private func scheduleReload(immediate: Bool) {
        refreshWork?.cancel()
        let work = DispatchWorkItem {
            let html = displayHTML
            if html != previewHTML || immediate {
                previewHTML = html
                refreshID = UUID()
            }
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (immediate ? 0 : 0.3), execute: work)
    }
}

struct HTMLWebView: NSViewRepresentable {
    let html: String
    let id: UUID
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator {
        var gate = ReloadGate()
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        // `drawsBackground` is private API — only touch it when the setter
        // actually exists, otherwise fall back to the default background.
        if webView.responds(to: Selector(("setDrawsBackground:"))) {
            webView.setValue(false, forKey: "drawsBackground")
        }
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.gate.shouldReload(id: id, html: html) else { return }
        webView.loadHTMLString(html, baseURL: nil)
    }
}
