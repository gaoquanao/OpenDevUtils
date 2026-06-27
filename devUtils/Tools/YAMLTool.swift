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
                input = NSPasteboard.general.string(forType: .string) ?? ""
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
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
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

// MARK: - Minimal YAML Parser

enum YAMLParse {
    static func parse(_ yaml: String) throws -> Any {
        let lines = yaml.components(separatedBy: "\n")
        var result: [String: Any] = [:]
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                i += 1
                continue
            }
            
            let indent = line.prefix(while: { $0 == " " }).count
            
            if trimmed.hasSuffix(":") {
                let key = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                i += 1
                if i < lines.count {
                    let nextLine = lines[i]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    let nextIndent = nextLine.prefix(while: { $0 == " " }).count
                    
                    if nextIndent > indent {
                        var subDict: [String: Any] = [:]
                        let subYaml = lines[i...].joined(separator: "\n")
                        subDict = try parseDict(subYaml, baseIndent: nextIndent)
                        result[key] = subDict
                        while i < lines.count && (lines[i].prefix(while: { $0 == " " }).count > indent || lines[i].trimmingCharacters(in: .whitespaces).isEmpty) {
                            i += 1
                        }
                        continue
                    } else if nextTrimmed.hasPrefix("- ") {
                        var arr: [Any] = []
                        while i < lines.count {
                            let l = lines[i].trimmingCharacters(in: .whitespaces)
                            if l.hasPrefix("- ") {
                                let val = String(l.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                                arr.append(parseValue(val))
                                i += 1
                            } else if lines[i].prefix(while: { $0 == " " }).count > indent {
                                i += 1
                            } else {
                                break
                            }
                        }
                        result[key] = arr
                        continue
                    } else {
                        let val = parseValue(nextTrimmed)
                        result[key] = val
                        i += 1
                        continue
                    }
                }
            } else if trimmed.hasPrefix("- ") {
                i += 1
                continue
            } else {
                i += 1
            }
        }
        
        return result
    }
    
    private static func parseDict(_ yaml: String, baseIndent: Int) throws -> [String: Any] {
        var dict: [String: Any] = [:]
        let lines = yaml.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            let indent = line.prefix(while: { $0 == " " }).count
            if indent != baseIndent { continue }
            
            if trimmed.hasSuffix(":") {
                let key = String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
                dict[key] = "" as Any
            } else if let colonIdx = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let val = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                dict[key] = parseValue(val)
            }
        }
        
        return dict
    }
    
    private static func parseValue(_ str: String) -> Any {
        let s = str.trimmingCharacters(in: .whitespaces)
        if s == "null" || s == "~" { return NSNull() }
        if s == "true" { return true }
        if s == "false" { return false }
        if let i = Int(s) { return i }
        if let d = Double(s) { return d }
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
            return String(s.dropFirst().dropLast())
        }
        return s
    }
}

// MARK: - Minimal YAML Emitter

enum YAMLEmit {
    static func emit(_ obj: Any, indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        
        if let dict = obj as? [String: Any] {
            var lines: [String] = []
            for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
                if let subDict = value as? [String: Any] {
                    lines.append("\(prefix)\(key):")
                    lines.append(emit(subDict, indent: indent + 1))
                } else if let arr = value as? [Any] {
                    lines.append("\(prefix)\(key):")
                    for item in arr {
                        if let itemDict = item as? [String: Any] {
                            let sub = emit(itemDict, indent: indent + 1)
                            let first = sub.components(separatedBy: "\n").first ?? ""
                            lines.append("\(prefix)  - \(first)")
                            let rest = sub.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
                            if !rest.isEmpty { lines.append(rest) }
                        } else {
                            lines.append("\(prefix)  - \(formatValue(item))")
                        }
                    }
                } else {
                    lines.append("\(prefix)\(key): \(formatValue(value))")
                }
            }
            return lines.joined(separator: "\n")
        } else if let arr = obj as? [Any] {
            return arr.map { "\(prefix)- \(formatValue($0))" }.joined(separator: "\n")
        }
        
        return formatValue(obj)
    }
    
    private static func formatValue(_ obj: Any) -> String {
        if obj is NSNull { return "null" }
        if let b = obj as? Bool { return b ? "true" : "false" }
        if let i = obj as? Int { return "\(i)" }
        if let d = obj as? Double { return "\(d)" }
        if let s = obj as? String {
            if s.contains(":") || s.contains("#") || s.contains("'") || s.contains("\"") {
                return "\"\(s.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return s
        }
        return "\(obj)"
    }
}
