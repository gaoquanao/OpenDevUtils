import SwiftUI
import WebKit

struct MarkdownPreviewTool: Tool {
    let id = "markdownPreview"
    let name = "Markdown Preview"
    let icon = "doc.richtext"
    let category: ToolCategory = .webDev
    
    @State private var markdown = ""
    @State private var previewHTML = ""
    @State private var refreshID = UUID()
    @State private var refreshWork: DispatchWorkItem?
    @ObservedObject private var lang = LanguageManager.shared
    
    private static let maxMDSize = 5_000_000 // 5MB input limit
    
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
        .onAppear { refreshPreview(immediate: true) }
    }
    
    private var header: some View {
        HStack {
            Text(L(.markdownPreview))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                markdown = PasteboardHelper.readString()
                refreshPreview(immediate: true)
            }
            Button(L(.refresh)) { refreshPreview(immediate: true) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.markdownInput)).font(.headline)
            TextEditor(text: $markdown)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .onChange(of: markdown) { _ in refreshPreview(immediate: false) }
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
    
    /// Debounced so typing doesn't re-render (and reload) the preview on
    /// every keystroke — that flashed white and lost the scroll position.
    /// An explicit Refresh/Paste bumps the id to force a reload.
    private func refreshPreview(immediate: Bool) {
        refreshWork?.cancel()
        let work = DispatchWorkItem {
            let html = Self.renderPreview(markdown)
            if html != previewHTML || immediate {
                previewHTML = html
                refreshID = UUID()
            }
        }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (immediate ? 0 : 0.3), execute: work)
    }
    
    private static func renderPreview(_ md: String) -> String {
        guard md.utf8.count < maxMDSize else {
            return "<p>Markdown too large (\(md.utf8.count / 1_000_000)MB), max 5MB</p>"
        }
        return MarkdownRenderer.render(md)
    }
}
