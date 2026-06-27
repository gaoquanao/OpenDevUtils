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
                markdown = PasteboardHelper.readString()
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
    
    private static let maxMDSize = 5_000_000 // 5MB input limit
    
    // Cache commonly used regex patterns
    private static let inlineCodeRegex = try! NSRegularExpression(pattern: "`([^`]+)`")
    private static let boldRegex = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*")
    private static let italicRegex = try! NSRegularExpression(pattern: "\\*(.+?)\\*")
    private static let linkRegex = try! NSRegularExpression(pattern: "\\[(.+?)\\]\\((.+?)\\)")
    private static let imageRegex = try! NSRegularExpression(pattern: "!\\[(.+?)\\]\\((.+?)\\)")
    
    private func markdownToHTML(_ md: String) -> String {
        // Size guard
        guard md.utf8.count < Self.maxMDSize else {
            return "<p>Markdown too large (\(md.utf8.count / 1_000_000)MB), max 5MB</p>"
        }
        
        let lines = md.components(separatedBy: "\n")
        var htmlLines: [String] = []
        var inCodeBlock = false
        var codeBlockLang = ""
        var codeBlockContent: [String] = []
        var inList = false
        var listType = ""
        
        for line in lines {
            // ── Code block (stateful) ──
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let escaped = codeBlockContent.map(escapeHTML).joined(separator: "\n")
                    let cls = codeBlockLang.isEmpty ? "" : " class=\"language-\(codeBlockLang)\""
                    htmlLines.append("<pre><code\(cls)>\(escaped)</code></pre>")
                    inCodeBlock = false
                    codeBlockContent = []
                    codeBlockLang = ""
                } else {
                    inCodeBlock = true
                    codeBlockLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if inCodeBlock {
                codeBlockContent.append(line)
                continue
            }
            
            // ── Process inline formatting ──
            var processed = line
            processed = applyInline(processed, regex: Self.imageRegex, template: "<img src=\"$2\" alt=\"$1\" style=\"max-width:100%\">")
            processed = applyInline(processed, regex: Self.linkRegex, template: "<a href=\"$2\">$1</a>")
            processed = applyInline(processed, regex: Self.boldRegex, template: "<strong>$1</strong>")
            processed = applyInline(processed, regex: Self.italicRegex, template: "<em>$1</em>")
            processed = applyInline(processed, regex: Self.inlineCodeRegex, template: "<code>$1</code>")
            
            // ── Block-level (check in priority order, single pass) ──
            if processed.hasPrefix("# ") {
                htmlLines.append("<h1>\(extractContent(processed, from: 2))</h1>")
                closeList(&inList, &listType, &htmlLines)
            } else if processed.hasPrefix("## ") {
                htmlLines.append("<h2>\(extractContent(processed, from: 3))</h2>")
                closeList(&inList, &listType, &htmlLines)
            } else if processed.hasPrefix("### ") {
                htmlLines.append("<h3>\(extractContent(processed, from: 4))</h3>")
                closeList(&inList, &listType, &htmlLines)
            } else if processed.hasPrefix("#### ") {
                htmlLines.append("<h4>\(extractContent(processed, from: 5))</h4>")
                closeList(&inList, &listType, &htmlLines)
            } else if processed.hasPrefix("> ") {
                htmlLines.append("<blockquote>\(extractContent(processed, from: 2))</blockquote>")
                closeList(&inList, &listType, &htmlLines)
            } else if processed == "---" {
                htmlLines.append("<hr>")
                closeList(&inList, &listType, &htmlLines)
            } else if processed.hasPrefix("- ") || processed.hasPrefix("* ") {
                let content = extractContent(processed, from: 2)
                if !inList || listType != "ul" { closeList(&inList, &listType, &htmlLines); htmlLines.append("<ul>"); inList = true; listType = "ul" }
                htmlLines.append("<li>\(content)</li>")
            } else if processed.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                let idx = processed.firstIndex(of: ".") ?? processed.endIndex
                let afterDot = processed[processed.index(after: idx)...].trimmingCharacters(in: .whitespaces)
                if !inList || listType != "ol" { closeList(&inList, &listType, &htmlLines); htmlLines.append("<ol>"); inList = true; listType = "ol" }
                htmlLines.append("<li>\(afterDot)</li>")
            } else {
                closeList(&inList, &listType, &htmlLines)
                if processed.isEmpty {
                    htmlLines.append("")
                } else {
                    htmlLines.append(processed)
                }
            }
        }
        
        // Close any open tags
        closeList(&inList, &listType, &htmlLines)
        if inCodeBlock {
            let escaped = codeBlockContent.map(escapeHTML).joined(separator: "\n")
            htmlLines.append("<pre><code>\(escaped)</code></pre>")
        }
        
        var html = htmlLines.joined(separator: "\n")
        
        // Paragraph wrapping (double newline → </p><p>)
        html = html.replacingOccurrences(of: "\n\n+", with: "</p><p>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        let css = """
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; line-height: 1.6; color: #333; }
            pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; }
            code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
            blockquote { border-left: 4px solid #ddd; margin: 0; padding: 8px 16px; color: #666; }
            img { max-width: 100%; }
            a { color: #0066cc; }
            h1, h2, h3, h4 { margin-top: 16px; margin-bottom: 8px; }
            li { margin-left: 20px; }
        """
        
        return """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>\(css)</style></head>
        <body><p>\(html)</p></body>
        </html>
        """
    }
    
    private func applyInline(_ text: String, regex: NSRegularExpression, template: String) -> String {
        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: nsRange, withTemplate: template)
    }
    
    private func extractContent(_ text: String, from offset: Int) -> String {
        let idx = text.index(text.startIndex, offsetBy: min(offset, text.count))
        return String(text[idx...]).trimmingCharacters(in: .whitespaces)
    }
    
    private func closeList(_ inList: inout Bool, _ listType: inout String, _ html: inout [String]) {
        guard inList else { return }
        html.append(listType == "ul" ? "</ul>" : "</ol>")
        inList = false
        listType = ""
    }
    
    private func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
