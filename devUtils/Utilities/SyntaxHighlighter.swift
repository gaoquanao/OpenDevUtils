import SwiftUI
import AppKit

/// Line tokenizer for syntax highlighting, extracted from the SwiftUI view so
/// it can be tested and cached. Fixes review findings:
/// - regexes were recompiled per token per line inside the inner loop
/// - the Go string rule was `"[^"]*`` (required a trailing backtick), so Go
///   strings were never highlighted
/// - force unwraps (`bestMatch!.range!`)
/// - string rules didn't handle backslash escapes
enum SyntaxHighlighter {

    enum TokenKind: Hashable {
        case plain
        case string
        case comment
        case keyword
        case type
        case function
        case variable
    }

    struct Token: Equatable {
        let text: String
        let kind: TokenKind
    }

    private struct Rule {
        let regex: NSRegularExpression
        let kind: TokenKind
    }

    // MARK: - Caches

    private static let lock = NSLock()
    private static var ruleCache: [String: [Rule]] = [:]
    private static var lineCache: [String: [Token]] = [:]
    private static let lineCacheLimit = 5_000

    // MARK: - Public API

    /// Tokenizes a single line. Tokens concatenated always reproduce the
    /// input exactly (no characters are dropped or altered).
    static func tokens(line: String, language: String) -> [Token] {
        guard !line.isEmpty else { return [] }

        let cacheKey = language + "\u{0}" + line
        lock.lock()
        if let cached = lineCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = tokenize(line: line, language: language)

        lock.lock()
        if lineCache.count >= lineCacheLimit {
            lineCache.removeAll()
        }
        lineCache[cacheKey] = result
        lock.unlock()
        return result
    }

    private static func tokenize(line: String, language: String) -> [Token] {
        let rules = compiledRules(for: language)
        guard !rules.isEmpty else { return [Token(text: line, kind: .plain)] }

        let ns = line as NSString
        let fullLength = ns.length
        var tokens: [Token] = []
        var position = 0

        while position < fullLength {
            var bestLocation = 0
            var bestLength = 0
            var bestKind = TokenKind.plain
            var found = false

            let searchRange = NSRange(location: position, length: fullLength - position)
            for rule in rules {
                guard let m = rule.regex.firstMatch(in: line, range: searchRange),
                      m.range.length > 0 else { continue }
                if !found || m.range.location < bestLocation {
                    found = true
                    bestLocation = m.range.location
                    bestLength = m.range.length
                    bestKind = rule.kind
                }
            }

            if found {
                if bestLocation > position {
                    tokens.append(Token(text: ns.substring(with: NSRange(location: position,
                                                                         length: bestLocation - position)),
                                        kind: .plain))
                }
                tokens.append(Token(text: ns.substring(with: NSRange(location: bestLocation,
                                                                     length: bestLength)),
                                    kind: bestKind))
                position = bestLocation + bestLength
            } else {
                tokens.append(Token(text: ns.substring(from: position), kind: .plain))
                break
            }
        }
        return tokens
    }

    // MARK: - Rule tables

    private static func compiledRules(for language: String) -> [Rule] {
        lock.lock()
        if let cached = ruleCache[language] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let built = patterns(for: language).compactMap { pair -> Rule? in
            guard let regex = try? NSRegularExpression(pattern: pair.pattern) else { return nil }
            return Rule(regex: regex, kind: pair.kind)
        }

        lock.lock()
        ruleCache[language] = built
        lock.unlock()
        return built
    }

    private static func patterns(for language: String) -> [(pattern: String, kind: TokenKind)] {
        switch language {
        case "Swift":
            return [
                (#""(?:\\.|[^"\\])*""#, .string),
                (#"//.*$"#, .comment),
                (#"\b(?:func|let|var|if|else|return|import|class|struct|enum|case|switch|for|while|guard|try|catch|throw|async|await|self|true|false|nil|in|where|static|public|private|init|extension|protocol|operator|subscript|typealias|defer|repeat|break|continue|is|as)\b"#, .keyword),
                (#"\b(?:Int|String|Bool|Double|Float|Data|URL|URLRequest|URLSession|Error|Any|Some|Array|Dictionary|Set|Optional|Character|UInt|Int64|CGFloat|Date)\b"#, .type),
                (#"\.[a-zA-Z_]\w*\s*\("#, .function),
            ]
        case "Python":
            return [
                (#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, .string),
                (#"//.*$"#, .comment),
                (#"(?<![#\w])#.*$"#, .comment),
                (#"\b(?:def|import|from|return|if|else|elif|for|while|class|try|except|finally|raise|with|as|in|not|and|or|is|None|True|False|lambda|pass|break|continue|global|yield|print)\b"#, .keyword),
                (#"\b(?:requests|json|os|sys|re|math|datetime|pathlib|typing)\b"#, .type),
                (#"\.[a-zA-Z_]\w*\s*\("#, .function),
            ]
        case "JavaScript":
            return [
                (#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, .string),
                (#"//.*$"#, .comment),
                (#"\b(?:const|let|var|function|return|if|else|for|while|class|import|export|from|async|await|try|catch|finally|new|this|typeof|instanceof|in|of|delete|void|switch|case|break|continue|do|default|throw|null|undefined|true|false)\b"#, .keyword),
                (#"\b(?:fetch|console|Promise|JSON|Response|Error|Object|Array|Math|Date|Map|Set)\b"#, .type),
                (#"\.[a-zA-Z_]\w*\s*\("#, .function),
            ]
        case "Go":
            return [
                (#""(?:\\.|[^"\\])*""#, .string),
                (#"`[^`]*`"#, .string),
                (#"//.*$"#, .comment),
                (#"\b(?:func|package|import|return|if|else|for|var|const|type|struct|map|defer|go|chan|select|range|interface|switch|case|break|continue|fallthrough|goto|nil|true|false|iota)\b"#, .keyword),
                (#"\b(?:string|int|int64|float64|bool|byte|error|uint8|uint|rune|http|fmt|io|strings|strconv|sync|context|json)\b"#, .type),
                (#"\.[A-Z][a-zA-Z]*\s*\("#, .function),
            ]
        case "PHP":
            return [
                (#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, .string),
                (#"//.*$|#.*$"#, .comment),
                (#"\$[A-Za-z_]\w*"#, .variable),
                (#"\b(?:echo|function|return|if|else|elseif|for|foreach|while|class|new|true|false|null|public|private|protected|static|use|namespace|switch|case|break|continue|try|catch|finally|throw|instanceof|as|const|var|global|isset|unset|empty|die|exit|require|include)\b"#, .keyword),
                (#"\b(?:curl|curl_init|curl_exec|curl_close|CURLOPT_[A-Z_]+|array_map|array_filter|strlen|json_encode|json_decode)\b"#, .type),
                (#"\.[a-zA-Z_]\w*\s*\("#, .function),
            ]
        case "Java":
            return [
                (#""(?:\\.|[^"\\])*""#, .string),
                (#"//.*$"#, .comment),
                (#"\b(?:public|private|protected|class|interface|enum|static|final|void|return|if|else|for|while|do|switch|case|break|continue|new|this|super|try|catch|finally|throw|throws|import|package|extends|implements|abstract|synchronized|volatile|transient|instanceof|null|true|false|var)\b"#, .keyword),
                (#"\b(?:String|int|boolean|long|double|float|byte|char|short|Object|List|Map|HttpClient|HttpRequest|HttpResponse|URI|System|Integer|Math)\b"#, .type),
                (#"\.[A-Z][a-zA-Z]*\s*\("#, .function),
            ]
        case "Shell":
            return [
                (#"'[^']*'|"(?:\\.|[^"\\])*""#, .string),
                (#"(?<!\w)#.*$"#, .comment),
                (#"\b(?:curl|wget|echo|export|cd|ls|cat|grep|sed|awk|find|source|alias|unset|exit|return|local|read|printf|exec|eval|set|test)\b"#, .keyword),
                (#"\B--?[A-Za-z][-\w]*"#, .variable),
                (#"\$[A-Za-z_]\w*"#, .variable),
            ]
        default:
            return []
        }
    }
}

// MARK: - Read-only highlighted code view

struct SyntaxHighlightedCode: View {
    let code: String
    let language: String

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(code.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    highlightedLine(line)
                }
            }
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
    }

    private func highlightedLine(_ line: String) -> some View {
        let tokens = SyntaxHighlighter.tokens(line: line, language: language)
        return HStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                Text(token.text)
                    .foregroundStyle(color(for: token.kind))
            }
        }
    }

    private func color(for kind: SyntaxHighlighter.TokenKind) -> Color {
        switch kind {
        case .plain: return .primary
        case .string: return .green
        case .comment: return .gray
        case .keyword: return .pink
        case .type: return .cyan
        case .function: return .yellow
        case .variable: return .orange
        }
    }
}

// MARK: - Editable highlighted text editor

/// A `TextEditor` replacement that highlights the input (used for the cURL
/// command field). Highlighting only touches attributes — never characters —
/// so undo, selection and typing behavior are preserved.
struct HighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let language: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        // This view manages its own text attributes (highlighting); opt out
        // of the window-level attribute wipe in DisableSmartQuotes.
        markTextViewAttributesManaged(textView)

        context.coordinator.parent = self
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            let selected = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selected
            context.coordinator.applyHighlighting(to: textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextEditor
        weak var textView: NSTextView?

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            let newText = textView.string
            if newText != parent.text {
                parent.text = newText
            }
            applyHighlighting(to: textView)
        }

        /// Applies token colors without modifying the text storage's
        /// characters (attributes only), so undo grouping is unaffected.
        func applyHighlighting(to textView: NSTextView) {
            guard let storage = textView.textStorage, storage.length > 0 else { return }

            let baseFont = textView.font
                ?? .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
            ]

            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: NSRange(location: 0, length: storage.length))

            let full = storage.string as NSString
            var offset = 0
            let lines = full.components(separatedBy: "\n")
            for line in lines {
                let lineLength = (line as NSString).length
                var column = 0
                for token in SyntaxHighlighter.tokens(line: line, language: parent.language) {
                    let tokenLength = (token.text as NSString).length
                    if let color = color(for: token.kind) {
                        storage.addAttribute(.foregroundColor,
                                             value: color,
                                             range: NSRange(location: offset + column,
                                                            length: tokenLength))
                    }
                    column += tokenLength
                }
                offset += lineLength + 1 // "\n"
            }
            storage.endEditing()
        }

        private func color(for kind: SyntaxHighlighter.TokenKind) -> NSColor? {
            switch kind {
            case .plain: return nil
            case .string: return .systemGreen
            case .comment: return .systemGray
            case .keyword: return .systemPink
            case .type: return .systemTeal
            case .function: return .systemYellow
            case .variable: return .systemOrange
            }
        }
    }
}
