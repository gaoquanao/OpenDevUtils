import SwiftUI

struct YAMLTool: Tool {
    let id = "yamlJson"
    let name = "YAML ↔ JSON"
    let icon = "arrow.left.arrow.right"
    let category: ToolCategory = .json
    
    @State private var input = ""
    @State private var output = ""
    @State private var direction: Direction = .yamlToJson
    @State private var errorMessage: String?
    @ObservedObject private var lang = LanguageManager.shared
    
    enum Direction: String, CaseIterable {
        case yamlToJson
        case jsonToYaml
    }
    
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
            Text(L(.yamlJsonConverter))
                .font(.title2.bold())
            Spacer()
            Picker("", selection: $direction) {
                Text(L(.yamlToJson)).tag(Direction.yamlToJson)
                Text(L(.jsonToYaml)).tag(Direction.jsonToYaml)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .onChange(of: direction) { _ in convert() }
            
            Button(L(.paste)) {
                input = PasteboardHelper.readString()
                convert()
            }
            Button(L(.convert)) { convert() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(direction == .yamlToJson ? L(.yamlInput) : L(.jsonInput)).font(.headline)
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
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
                Text(direction == .yamlToJson ? L(.jsonOutput) : L(.yamlOutput)).font(.headline)
                Spacer()
                Button(L(.copy)) {
                    PasteboardHelper.writeString(output)
                }
                .disabled(output.isEmpty)
            }
            TextEditor(text: .constant(output))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .border(.quaternary, width: 1)
                .frame(minWidth: 200, minHeight: 200, maxHeight: .infinity)
                .textSelection(.enabled)
        }
        .padding(.leading, 8)
    }
    
    private func convert() {
        errorMessage = nil
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""; return
        }
        
        switch direction {
        case .yamlToJson:
            convertYamlToJson()
        case .jsonToYaml:
            convertJsonToYaml()
        }
    }
    
    private func convertYamlToJson() {
        do {
            let obj = try YAMLParse.parse(input)
            let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
            output = String(data: data, encoding: .utf8) ?? ""
        } catch {
            errorMessage = error.localizedDescription
            output = ""
        }
    }
    
    private func convertJsonToYaml() {
        guard let data = input.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            errorMessage = L(.invalidJSON)
            output = ""
            return
        }
        output = YAMLEmit.emit(json)
    }
}

// MARK: - YAML Parser

enum YAMLError: LocalizedError, CustomStringConvertible {
    case message(String)

    var description: String {
        if case .message(let text) = self { return text }
        return ""
    }
    var errorDescription: String? { description }
}

enum YAMLParse {
    static func parse(_ yaml: String) throws -> Any {
        // Split multi-document input on `---` markers.
        var docs: [[String]] = [[]]
        for raw in yaml.components(separatedBy: "\n") {
            if raw.trimmingCharacters(in: .whitespaces) == "---" {
                docs.append([])
            } else {
                docs[docs.count - 1].append(raw)
            }
        }

        func isSignificant(_ doc: [String]) -> Bool {
            doc.contains { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return !t.isEmpty && !t.hasPrefix("#")
            }
        }

        let significant = docs.filter(isSignificant)
        if significant.count > 1 {
            return try significant.map { try Parser(rawLines: $0).parseDocument() }
        }
        let doc = significant.first ?? docs[0]
        return try Parser(rawLines: doc).parseDocument()
    }

    private final class Parser {
        struct Line {
            let indent: Int
            let text: String
        }

        private var lines: [Line] = []
        private var index = 0
        private var anchors: [String: Any] = [:]

        init(rawLines: [String]) throws {
            for raw in rawLines {
                let leading = raw.prefix { $0 == " " || $0 == "\t" }
                if leading.contains("\t") {
                    throw YAMLError.message("Tab indentation is not allowed: \(raw)")
                }
                let indent = raw.prefix(while: { $0 == " " }).count
                let unindented = String(raw.dropFirst(indent))
                let trimmedWhole = unindented.trimmingCharacters(in: .whitespaces)
                if trimmedWhole.isEmpty || trimmedWhole.hasPrefix("#") { continue }

                let text = stripComment(unindented).trimmingCharacters(in: .whitespaces)
                if text.isEmpty { continue }
                lines.append(Line(indent: indent, text: text))
            }
        }

        func parseDocument() throws -> Any {
            guard !lines.isEmpty else { return [String: Any]() }
            let value = try parseBlock(at: lines[index].indent)
            if index < lines.count {
                throw YAMLError.message("Unable to parse line: \(lines[index].text)")
            }
            return value
        }

        // MARK: Blocks

        private func parseBlock(at indent: Int) throws -> Any {
            if isSeqItem(lines[index].text) {
                return try parseSequence(at: indent)
            }
            return try parseMapping(at: indent)
        }

        private func parseMapping(at indent: Int) throws -> [String: Any] {
            var explicit: [String: Any] = [:]
            var merged: [String: Any] = [:]

            while index < lines.count {
                let line = lines[index]
                if line.indent < indent { break }
                if isSeqItem(line.text) { break }
                if line.indent > indent {
                    throw YAMLError.message("Unexpected indentation: \(line.text)")
                }
                guard let pair = splitKey(line.text) else {
                    throw YAMLError.message("Unable to parse line: \(line.text)")
                }
                index += 1

                var anchorName: String?
                var valueText = pair.value
                if valueText.hasPrefix("&") {
                    let parts = valueText.split(separator: " ", maxSplits: 1,
                                                omittingEmptySubsequences: true)
                    anchorName = String(parts[0].dropFirst())
                    valueText = parts.count > 1 ? String(parts[1]) : ""
                }

                let value: Any
                if valueText.isEmpty {
                    if index < lines.count && lines[index].indent > indent {
                        value = try parseBlock(at: lines[index].indent)
                    } else if index < lines.count, lines[index].indent == indent,
                              isSeqItem(lines[index].text) {
                        value = try parseSequence(at: indent)
                    } else {
                        value = NSNull()
                    }
                } else {
                    value = try parseInlineValue(valueText)
                }

                if let anchor = anchorName {
                    anchors[anchor] = value
                }

                if pair.key == "<<" {
                    if let dict = value as? [String: Any] {
                        for (k, v) in dict { merged[k] = v }
                    }
                } else {
                    explicit[pair.key] = value
                }
            }

            var result = merged
            for (k, v) in explicit { result[k] = v }
            return result
        }

        private func parseSequence(at indent: Int) throws -> [Any] {
            var array: [Any] = []

            while index < lines.count {
                let line = lines[index]
                if line.indent != indent || !isSeqItem(line.text) { break }

                let content: String
                if line.text == "-" {
                    content = ""
                } else {
                    content = String(line.text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }

                if content.isEmpty {
                    index += 1
                    if index < lines.count && lines[index].indent > indent {
                        array.append(try parseBlock(at: lines[index].indent))
                    } else {
                        array.append(NSNull())
                    }
                    continue
                }

                if splitKey(content) != nil {
                    // Mapping entry: reposition this line at the content column
                    // and let the mapping parser consume its continuation lines.
                    let spacesAfterDash = line.text.dropFirst(1).prefix(while: { $0 == " " }).count
                    let contentColumn = indent + 1 + spacesAfterDash
                    lines[index] = Line(indent: contentColumn, text: content)
                    array.append(try parseMapping(at: contentColumn))
                    continue
                }

                array.append(try parseInlineValue(content))
                index += 1
            }

            return array
        }

        // MARK: Values

        private func parseInlineValue(_ text: String) throws -> Any {
            if text.hasPrefix("*") {
                let name = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                guard let value = anchors[name] else {
                    throw YAMLError.message("Unknown alias: *\(name)")
                }
                return value
            }

            if text.hasPrefix("&") {
                let parts = text.split(separator: " ", maxSplits: 1,
                                       omittingEmptySubsequences: true)
                let name = String(parts[0].dropFirst())
                guard parts.count > 1 else {
                    throw YAMLError.message("Anchor without a value: \(text)")
                }
                let value = try parseInlineValue(String(parts[1]))
                anchors[name] = value
                return value
            }

            if text.hasPrefix("["), text.hasSuffix("]") {
                let inner = String(text.dropFirst().dropLast())
                if inner.trimmingCharacters(in: .whitespaces).isEmpty { return [Any]() }
                return try splitFlow(inner).map { try parseInlineValue($0) }
            }

            if text.hasPrefix("{"), text.hasSuffix("}") {
                let inner = String(text.dropFirst().dropLast())
                var dict: [String: Any] = [:]
                if !inner.trimmingCharacters(in: .whitespaces).isEmpty {
                    for part in splitFlow(inner) {
                        guard let pair = splitKey(part) else { continue }
                        dict[pair.key] = try parseInlineValue(pair.value)
                    }
                }
                return dict
            }

            return scalar(text)
        }

        private func scalar(_ s: String) -> Any {
            if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
                return String(s.dropFirst().dropLast())
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            }
            if s.count >= 2, s.hasPrefix("'"), s.hasSuffix("'") {
                return String(s.dropFirst().dropLast())
                    .replacingOccurrences(of: "''", with: "'")
            }
            switch s {
            case "null", "Null", "NULL", "~":
                return NSNull()
            case "true", "True", "TRUE":
                return true
            case "false", "False", "FALSE":
                return false
            default:
                break
            }
            if let i = Int(s) { return i }
            if let d = Double(s) { return d }
            return s
        }

        // MARK: Lexing helpers

        private func isSeqItem(_ text: String) -> Bool {
            text == "-" || text.hasPrefix("- ")
        }

        /// Splits `key: value` at the first colon outside quotes that is
        /// followed by whitespace or end-of-line.
        private func splitKey(_ text: String) -> (key: String, value: String)? {
            var quote: Character?
            var escape = false
            let chars = Array(text)
            var i = 0
            while i < chars.count {
                let c = chars[i]
                if escape { escape = false; i += 1; continue }
                if let q = quote {
                    if q == "\"" && c == "\\" { escape = true; i += 1; continue }
                    if c == q { quote = nil }
                    i += 1
                    continue
                }
                if c == "\"" || c == "'" { quote = c; i += 1; continue }
                if c == ":" {
                    let next = i + 1 < chars.count ? chars[i + 1] : nil
                    if next == nil || next == " " || next == "\t" {
                        let key = String(chars[..<i]).trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty else { return nil }
                        let value = String(chars[(i + 1)...]).trimmingCharacters(in: .whitespaces)
                        return (key, value)
                    }
                }
                i += 1
            }
            return nil
        }

        /// Splits a flow collection body on top-level commas.
        private func splitFlow(_ text: String) -> [String] {
            var parts: [String] = []
            var depth = 0
            var quote: Character?
            var escape = false
            var current = ""
            for c in text {
                if escape { current.append(c); escape = false; continue }
                if let q = quote {
                    current.append(c)
                    if q == "\"" && c == "\\" { escape = true; continue }
                    if c == q { quote = nil }
                    continue
                }
                if c == "\"" || c == "'" { quote = c; current.append(c); continue }
                if c == "[" || c == "{" { depth += 1; current.append(c); continue }
                if c == "]" || c == "}" { depth -= 1; current.append(c); continue }
                if c == "," && depth == 0 {
                    parts.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                    continue
                }
                current.append(c)
            }
            if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                parts.append(current.trimmingCharacters(in: .whitespaces))
            }
            return parts
        }

        /// Removes a trailing `# comment` (must be preceded by whitespace and
        /// outside quotes, so `https://x.com/a#b` keeps its fragment).
        private func stripComment(_ text: String) -> String {
            var quote: Character?
            var escape = false
            let chars = Array(text)
            var i = 0
            while i < chars.count {
                let c = chars[i]
                if escape { escape = false; i += 1; continue }
                if let q = quote {
                    if q == "\"" && c == "\\" { escape = true; i += 1; continue }
                    if c == q { quote = nil }
                    i += 1
                    continue
                }
                if c == "\"" || c == "'" { quote = c; i += 1; continue }
                if c == "#" {
                    if i == 0 || chars[i - 1] == " " || chars[i - 1] == "\t" {
                        return String(chars[..<i])
                    }
                }
                i += 1
            }
            return text
        }
    }
}

// MARK: - Minimal YAML Emitter

enum YAMLEmit {
    static func emit(_ obj: Any, indent: Int = 0) -> String {
        if let dict = obj as? [String: Any] {
            guard !dict.isEmpty else { return "{}" }
            let prefix = String(repeating: "  ", count: indent)
            var lines: [String] = []
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                if let subDict = value as? [String: Any] {
                    if subDict.isEmpty {
                        lines.append("\(prefix)\(key): {}")
                    } else {
                        lines.append("\(prefix)\(key):")
                        lines.append(emit(subDict, indent: indent + 1))
                    }
                } else if let arr = value as? [Any] {
                    if arr.isEmpty {
                        lines.append("\(prefix)\(key): []")
                    } else {
                        lines.append("\(prefix)\(key):")
                        lines.append(emitArray(arr, indent: indent + 1))
                    }
                } else {
                    lines.append("\(prefix)\(key): \(formatValue(value))")
                }
            }
            return lines.joined(separator: "\n")
        }

        if let arr = obj as? [Any] {
            guard !arr.isEmpty else { return "[]" }
            return emitArray(arr, indent: indent)
        }

        return formatValue(obj)
    }

    /// Emits a sequence whose items are aligned at `indent` levels.
    /// Nested sequences/dictionaries are emitted relative to the `- ` marker.
    private static func emitArray(_ arr: [Any], indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)
        let childPrefixLength = (indent + 1) * 2
        var lines: [String] = []

        for item in arr {
            if let subDict = item as? [String: Any] {
                if subDict.isEmpty {
                    lines.append("\(prefix)- {}")
                    continue
                }
                var subLines = emit(subDict, indent: indent + 1).components(separatedBy: "\n")
                let first = subLines.removeFirst()
                lines.append("\(prefix)- \(strip(first, upTo: childPrefixLength))")
                lines.append(contentsOf: subLines)
            } else if let subArr = item as? [Any] {
                if subArr.isEmpty {
                    lines.append("\(prefix)- []")
                    continue
                }
                var subLines = emitArray(subArr, indent: indent + 1).components(separatedBy: "\n")
                let first = subLines.removeFirst()
                lines.append("\(prefix)- \(strip(first, upTo: childPrefixLength))")
                lines.append(contentsOf: subLines)
            } else {
                lines.append("\(prefix)- \(formatValue(item))")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func strip(_ line: String, upTo length: Int) -> String {
        String(line.dropFirst(Swift.min(length, line.count)))
    }

    private static func formatValue(_ obj: Any) -> String {
        if obj is NSNull { return "null" }
        // `NSNumber(1) as? Bool` succeeds, so a plain `as? Bool` check would
        // turn JSON numbers 0/1 into `false`/`true`. Only CFBoolean instances
        // (JSON true/false and Swift Bool) are booleans.
        if let number = obj as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            if let i = number as? Int, !number.stringValue.contains(".") {
                return "\(i)"
            }
            return "\(number.doubleValue)"
        }
        if let b = obj as? Bool { return b ? "true" : "false" }
        if let i = obj as? Int { return "\(i)" }
        if let d = obj as? Double { return "\(d)" }
        if let s = obj as? String {
            if needsQuoting(s) {
                let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                return "\"\(escaped)\""
            }
            return s
        }
        return "\(obj)"
    }

    /// Strings that YAML would re-parse as another type (numbers, booleans,
    /// null) or that contain structural characters must be quoted, otherwise
    /// the type is lost on a round trip.
    private static func needsQuoting(_ s: String) -> Bool {
        if s.isEmpty { return true }
        if Int(s) != nil || Double(s) != nil { return true }
        switch s.lowercased() {
        case "true", "false", "null", "~", "yes", "no", "on", "off":
            return true
        default:
            break
        }
        if s.contains(where: { ":#'\"\n\r\\".contains($0) }) { return true }
        if let first = s.first, "-?[]{},&*!|>%@`".contains(first) { return true }
        return false
    }
}
