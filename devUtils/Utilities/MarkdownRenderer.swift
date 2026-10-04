import Foundation

/// Markdown → HTML extracted from `MarkdownPreviewTool` so the conversion is
/// testable and cacheable. Fixes review findings:
/// - global `\n` → `<br>` replacement corrupted `<pre>` code blocks
/// - non-code text was never HTML-escaped (`<`, `&` parsed as markup)
/// - emphasis ran before inline code, so `` `**x**` `` became formatted
/// - block elements were wrapped in a single `<p>`
enum MarkdownRenderer {

    static func render(_ markdown: String) -> String {
        let body = renderBody(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><style>\(css)</style></head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Block level

    private static func renderBody(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var out: [String] = []
        var paragraph: [String] = []
        var listType: String? = nil       // "ul" / "ol"
        var listItems: [String] = []
        var inCodeBlock = false
        var codeLang = ""
        var codeLines: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            let content = paragraph.map(inline).joined(separator: "<br>")
            out.append("<p>\(content)</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard let type = listType else { return }
            out.append("<\(type)>")
            out.append(contentsOf: listItems.map { "<li>\($0)</li>" })
            out.append("</\(type)>")
            listType = nil
            listItems.removeAll()
        }

        func flushAll() {
            flushParagraph()
            flushList()
        }

        for line in lines {
            // ── Fenced code block ──
            if line.hasPrefix("```") {
                if inCodeBlock {
                    let escaped = codeLines.map(escape).joined(separator: "\n")
                    let cls = codeLang.isEmpty ? "" : " class=\"language-\(codeLang)\""
                    out.append("<pre><code\(cls)>\(escaped)</code></pre>")
                    inCodeBlock = false
                    codeLang = ""
                    codeLines.removeAll()
                } else {
                    flushAll()
                    inCodeBlock = true
                    codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Blank line ends any open block.
            if trimmed.isEmpty {
                flushAll()
                continue
            }

            // Horizontal rule (check before lists: `---`, `***`).
            if trimmed == "---" || trimmed == "***" || trimmed == "___" ||
                trimmed == "- - -" || trimmed == "* * *" {
                flushAll()
                out.append("<hr>")
                continue
            }

            // Heading
            if let m = firstMatch(line, pattern: #"^(#{1,6})\s+(.*)$"#) {
                flushAll()
                let level = m.groups[0].count
                out.append("<h\(level)>\(inline(m.groups[1]))</h\(level)>")
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                flushAll()
                let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : ""
                out.append("<blockquote>\(inline(content))</blockquote>")
                continue
            }

            // Unordered list
            if let m = firstMatch(line, pattern: #"^[-*+]\s+(.*)$"#) {
                flushParagraph()
                if listType != "ul" {
                    flushList()
                    listType = "ul"
                }
                listItems.append(inline(m.groups[0]))
                continue
            }

            // Ordered list
            if let m = firstMatch(line, pattern: #"^\d+\.\s+(.*)$"#) {
                flushParagraph()
                if listType != "ol" {
                    flushList()
                    listType = "ol"
                }
                listItems.append(inline(m.groups[0]))
                continue
            }

            // Plain text → paragraph
            flushList()
            paragraph.append(line)
        }

        if inCodeBlock {
            let escaped = codeLines.map(escape).joined(separator: "\n")
            out.append("<pre><code>\(escaped)</code></pre>")
        }
        flushAll()

        return out.joined(separator: "\n")
    }

    // MARK: - Inline level

    private static func inline(_ text: String) -> String {
        var codeSpans: [String] = []

        // 1. Extract code spans first so escaping/emphasis can't touch them.
        let working = replacing(text, pattern: "`([^`\n]+)`") { m, ns in
            let code = escape(ns.substring(with: m.range(at: 1)))
            codeSpans.append("<code>\(code)</code>")
            return "\u{1}\(codeSpans.count - 1)\u{1}"
        }

        // 2. Escape everything else.
        var html = escape(working)

        // 3. Images before links (`![a](b)` also matches the link shape).
        html = replacing(html, pattern: #"!\[([^\]]*)\]\(([^)]*)\)"#) { m, ns in
            let alt = ns.substring(with: m.range(at: 1))
            let src = ns.substring(with: m.range(at: 2))
            return "<img src=\"\(src)\" alt=\"\(alt)\" style=\"max-width:100%\">"
        }

        // 4. Links
        html = replacing(html, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#) { m, ns in
            let label = ns.substring(with: m.range(at: 1))
            let href = ns.substring(with: m.range(at: 2))
            return "<a href=\"\(href)\">\(label)</a>"
        }

        // 5. Bold, then italic (bold must win over `**`).
        html = replacing(html, pattern: #"\*\*(.+?)\*\*"#) { m, ns in
            "<strong>\(ns.substring(with: m.range(at: 1)))</strong>"
        }
        html = replacing(html, pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#) { m, ns in
            "<em>\(ns.substring(with: m.range(at: 1)))</em>"
        }

        // 6. Restore code spans (already escaped when extracted).
        html = replacing(html, pattern: "\u{1}(\\d+)\u{1}") { m, ns in
            guard let idx = Int(ns.substring(with: m.range(at: 1))),
                  codeSpans.indices.contains(idx) else { return "" }
            return codeSpans[idx]
        }

        return html
    }

    // MARK: - Helpers

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func replacing(_ text: String,
                                  pattern: String,
                                  _ transform: (NSTextCheckingResult, NSString) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        var out = ""
        var last = 0
        for m in regex.matches(in: text, range: range) {
            if m.range.location > last {
                out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            }
            out += transform(m, ns)
            last = NSMaxRange(m.range)
        }
        if last < ns.length {
            out += ns.substring(from: last)
        }
        return out
    }

    private struct SimpleMatch {
        let groups: [String]
    }

    private static func firstMatch(_ text: String, pattern: String) -> SimpleMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1 else { return nil }
        var groups: [String] = []
        for i in 1..<m.numberOfRanges where m.range(at: i).location != NSNotFound {
            groups.append(ns.substring(with: m.range(at: i)))
        }
        return SimpleMatch(groups: groups)
    }

    private static let css = """
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; line-height: 1.6; color: #333; }
        pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; white-space: pre-wrap; }
        code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
        pre code { padding: 0; background: none; }
        blockquote { border-left: 4px solid #ddd; margin: 8px 0; padding: 8px 16px; color: #666; }
        img { max-width: 100%; }
        a { color: #0066cc; }
        h1, h2, h3, h4, h5, h6 { margin-top: 16px; margin-bottom: 8px; }
        li { margin-left: 20px; }
        """
}
