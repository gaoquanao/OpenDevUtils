import SwiftUI

struct SyntaxHighlightedCode: View {
    let code: String
    let language: String
    
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            highlightedText
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
    }
    
    private var highlightedText: some View {
        let lines = code.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                highlightLine(line)
            }
        }
    }
    
    private func highlightLine(_ line: String) -> some View {
        let tokens = tokenize(line)
        return HStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                Text(token.text)
                    .foregroundStyle(token.color)
            }
        }
    }
    
    private struct Token {
        let text: String
        let color: Color
    }
    
    private func tokenize(_ line: String) -> [Token] {
        let rules = getRules()
        var tokens: [Token] = []
        var remaining = line[...]
        
        while !remaining.isEmpty {
            var bestMatch: (range: Range<String.Index>?, color: Color)?
            
            for rule in rules {
                if let regex = try? NSRegularExpression(pattern: rule.pattern),
                   let match = regex.firstMatch(in: String(remaining), range: NSRange(remaining.startIndex..., in: remaining)),
                   let range = Range(match.range, in: remaining) {
                    if bestMatch == nil || range.lowerBound < bestMatch!.range!.lowerBound {
                        bestMatch = (range, rule.color)
                    }
                }
            }
            
            if let match = bestMatch, let range = match.range {
                if range.lowerBound > remaining.startIndex {
                    let plain = String(remaining[remaining.startIndex..<range.lowerBound])
                    tokens.append(Token(text: plain, color: .primary))
                }
                let matched = String(remaining[range])
                tokens.append(Token(text: matched, color: match.color))
                remaining = remaining[range.upperBound...]
            } else {
                tokens.append(Token(text: String(remaining), color: .primary))
                remaining = remaining[remaining.endIndex...]
            }
        }
        
        return tokens
    }
    
    private func getRules() -> [(pattern: String, color: Color)] {
        switch language {
        case "Swift":
            return [
                ("\"[^\"]*\"", .green),
                ("//.*$", .gray),
                ("\\b(func|let|var|if|else|return|import|class|struct|enum|case|switch|for|while|guard|try|catch|throw|async|await|self|true|false|nil|print)\\b", .pink),
                ("\\b(Int|String|Bool|Double|Float|Data|URL|URLRequest|URLSession|Error|Any|Some)\\b", .cyan),
                ("\\.[a-zA-Z_]+\\s*\\(", .yellow),
            ]
        case "Python":
            return [
                ("\"[^\"]*\"|'[^']*'", .green),
                ("#.*$", .gray),
                ("\\b(def|import|from|return|if|else|elif|for|while|class|try|except|raise|with|as|True|False|None|print|in|not|and|or)\\b", .pink),
                ("\\b(requests|json|os|sys|re|math|datetime)\\b", .cyan),
                ("\\.[a-zA-Z_]+\\s*\\(", .yellow),
            ]
        case "JavaScript":
            return [
                ("\"[^\"]*\"|'[^']*'|`[^`]*`", .green),
                ("//.*$", .gray),
                ("\\b(const|let|var|function|return|if|else|for|while|class|import|export|from|async|await|try|catch|new|this|true|false|null|undefined|typeof|instanceof)\\b", .pink),
                ("\\b(fetch|console|Promise|JSON|Response|Error|Object|Array|Math)\\b", .cyan),
                ("\\.[a-zA-Z_]+\\s*\\(", .yellow),
            ]
        case "Go":
            return [
                ("\"[^\"]*`", .green),
                ("//.*$", .gray),
                ("\\b(func|package|import|return|if|else|for|var|const|type|struct|map|defer|go|chan|select|range|interface|string|int|float64|bool|byte|error|nil|true|false)\\b", .pink),
                ("\\b(http|fmt|io|strings|strconv|sync|context|json)\\b", .cyan),
                ("\\.[A-Z][a-zA-Z]+\\s*\\(", .yellow),
            ]
        case "PHP":
            return [
                ("\"[^\"]*\"|'[^']*'", .green),
                ("//.*$|#.*$", .gray),
                ("\\b(echo|function|return|if|else|for|while|class|new|true|false|null|public|private|static|use|namespace)\\b", .pink),
                ("\\$[a-zA-Z_]+", .orange),
                ("\\b(curl|CURLOPT_[A-Z_]+|curl_init|curl_exec|curl_close)\\b", .cyan),
            ]
        case "Java":
            return [
                ("\"[^\"]*\"", .green),
                ("//.*$", .gray),
                ("\\b(public|private|protected|class|static|void|return|if|else|for|while|new|String|int|boolean|null|true|false|throws|try|catch|final|extends|implements|import|package)\\b", .pink),
                ("\\b(HttpClient|HttpRequest|HttpResponse|URI|BodyPublishers|String|System|List|Map)\\b", .cyan),
                ("\\.[A-Z][a-zA-Z]+\\s*\\(", .yellow),
            ]
        default:
            return []
        }
    }
}
