import SwiftUI
import WebKit

struct MarkdownPreviewTool: Tool {
    let id = "markdownPreview"
    let name = "Markdown Preview"
    let icon = "doc.richtext"
    let category: ToolCategory = .webDev
    
    @State private var markdown = ""
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
            Text(L(.markdownPreview))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                markdown = NSPasteboard.general.string(forType: .string) ?? ""
                refreshID = UUID()
            }
            Button(L(.refresh)) { refreshID = UUID() }
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
                .onChange(of: markdown) { _ in refreshID = UUID() }
        }
        .padding(.trailing, 8)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.preview)).font(.headline)
                Spacer()
            }
            HTMLWebView(html: markdownToHTML(markdown), id: refreshID)
                .border(.quaternary, width: 1)
        }
        .padding(.leading, 8)
    }
    
    private func markdownToHTML(_ md: String) -> String {
        var html = md
        
        // Code blocks
        html = html.replacingOccurrences(of: "```(\\w*)\\n([\\s\\S]*?)```",
            with: "<pre><code class=\"language-$1\">$2</code></pre>",
            options: .regularExpression)
        
        // Inline code
        html = html.replacingOccurrences(of: "`([^`]+)`",
            with: "<code>$1</code>",
            options: .regularExpression)
        
        // Bold
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>",
            options: .regularExpression)
        
        // Italic
        html = html.replacingOccurrences(of: "\\*(.+?)\\*",
            with: "<em>$1</em>",
            options: .regularExpression)
        
        // Headers
        html = html.replacingOccurrences(of: "^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)
        
        // Blockquote
        html = html.replacingOccurrences(of: "^> (.+)$", with: "<blockquote>$1</blockquote>", options: .regularExpression)
        
        // Horizontal rule
        html = html.replacingOccurrences(of: "^---$", with: "<hr>", options: .regularExpression)
        
        // Links
        html = html.replacingOccurrences(of: "\\[(.+?)\\]\\((.+?)\\)",
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression)
        
        // Images
        html = html.replacingOccurrences(of: "!\\[(.+?)\\]\\((.+?)\\)",
            with: "<img src=\"$2\" alt=\"$1\" style=\"max-width:100%\">",
            options: .regularExpression)
        
        // Unordered lists
        html = html.replacingOccurrences(of: "^- (.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        // Ordered lists
        html = html.replacingOccurrences(of: "^\\d+\\. (.+)$", with: "<li>$1</li>", options: .regularExpression)
        
        // Line breaks
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        // Wrap in HTML
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; line-height: 1.6; color: #333; }
            pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; }
            code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
            blockquote { border-left: 4px solid #ddd; margin: 0; padding: 8px 16px; color: #666; }
            img { max-width: 100%; }
            a { color: #0066cc; }
            h1, h2, h3, h4 { margin-top: 16px; margin-bottom: 8px; }
            li { margin-left: 20px; }
        </style>
        </head>
        <body><p>\(html)</p></body>
        </html>
        """
    }
}
