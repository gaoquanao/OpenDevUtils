import SwiftUI

struct CurlConverterTool: Tool {
    let id = "curlConverter"
    let name = "cURL Converter"
    let icon: String = "arrow.triangle.branch"
    let category: ToolCategory = .webDev
    
    @State private var curlCommand = ""
    @State private var selectedLanguage: CodeLanguage = .swift
    @State private var outputCode = ""
    @State private var parsedParts: ParsedCurl?
    @State private var showCopied = false
    @State private var convertWork: DispatchWorkItem?
    @ObservedObject private var lang = LanguageManager.shared
    
    enum CodeLanguage: String, CaseIterable, Identifiable {
        case swift = "Swift"
        case python = "Python"
        case javascript = "JavaScript"
        case go = "Go"
        case php = "PHP"
        case java = "Java"
        
        var id: String { rawValue }
    }
    
    struct ParsedCurl {
        var method: String = "GET"
        var url: String = ""
        var headers: [(String, String)] = []
        var body: String = ""
        var insecure: Bool = false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                inputSection
                languagePicker
                outputSection
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.curlConverter))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                curlCommand = PasteboardHelper.readString()
                convert()
            }
            Button(L(.clear)) {
                curlCommand = ""
                outputCode = ""
                parsedParts = nil
                convertWork?.cancel()
            }
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.curlInput)).font(.headline)
            HighlightedTextEditor(text: $curlCommand, language: "Shell")
                .border(.quaternary, width: 1)
                .frame(minHeight: 120)
                .onChange(of: curlCommand) { _ in scheduleConvert() }
        }
    }
    
    private var languagePicker: some View {
        HStack(spacing: 8) {
            Text(L(.language) + ":").font(.headline)
            ForEach(CodeLanguage.allCases) { lang in
                Button {
                    selectedLanguage = lang
                    convert()
                } label: {
                    Text(lang.rawValue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selectedLanguage == lang ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .foregroundColor(selectedLanguage == lang ? .white : .primary)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.output)).font(.headline)
                Spacer()
                if let parts = parsedParts, parts.url.isEmpty, !curlCommand.isEmpty {
                    Label(L(.urlNotFound), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Button(showCopied ? L(.copied) : L(.copy)) {
                    PasteboardHelper.writeString(outputCode)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopied = false
                    }
                }
                .disabled(outputCode.isEmpty)
            }
            SyntaxHighlightedCode(code: outputCode, language: selectedLanguage.rawValue)
                .frame(minHeight: 150, maxHeight: .infinity)
        }
    }
    
    /// Debounce: re-highlighting the output on every keystroke is wasteful
    /// while the user is still typing a long cURL command.
    private func scheduleConvert() {
        convertWork?.cancel()
        let work = DispatchWorkItem { convert() }
        convertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    
    private func convert() {
        let parsed = Self.parseCurl(curlCommand)
        parsedParts = parsed
        
        switch selectedLanguage {
        case .swift: outputCode = Self.generateSwift(parsed)
        case .python: outputCode = Self.generatePython(parsed)
        case .javascript: outputCode = Self.generateJavaScript(parsed)
        case .go: outputCode = Self.generateGo(parsed)
        case .php: outputCode = Self.generatePHP(parsed)
        case .java: outputCode = Self.generateJava(parsed)
        }
    }
    
    /// Shell-style tokenizer: honors single/double quotes, backslash escapes
    /// and line continuations, so quoted values (URLs, JSON bodies, headers)
    /// arrive as single tokens with quotes already stripped.
    static func tokenize(_ command: String) -> [String] {
        let normalized = command
            .replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        var tokens: [String] = []
        var current = ""
        var hasToken = false
        var quote: Character? = nil
        var escaped = false

        for character in normalized {
            if escaped {
                current.append(character)
                hasToken = true
                escaped = false
                continue
            }
            if character == "\\" {
                escaped = true
                hasToken = true
                continue
            }
            if character == "'" || character == "\"" {
                if quote == nil {
                    quote = character
                    hasToken = true
                } else if quote == character {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }
            if quote == nil && (character == " " || character == "\t" || character == "\n") {
                if hasToken {
                    tokens.append(current)
                    current = ""
                    hasToken = false
                }
                continue
            }
            current.append(character)
            hasToken = true
        }
        if hasToken {
            tokens.append(current)
        }
        return tokens
    }

    static func parseCurl(_ command: String) -> ParsedCurl {
        var result = ParsedCurl()
        let tokens = tokenize(command)

        let valueOptions: Set<String> = [
            "-X", "--request",
            "-H", "--header",
            "-d", "--data", "--data-raw", "--data-binary", "--data-urlencode",
            "-u", "--user",
            "-o", "--output",
            "-A", "--user-agent",
            "-e", "--referer",
            "-b", "--cookie",
            "-m", "--max-time",
            "--connect-timeout",
        ]

        var index = 0
        while index < tokens.count {
            var token = tokens[index]

            // Long option with attached value: `--header=...`, `--request=POST`.
            var attached: String?
            if token.hasPrefix("--"), let eq = token.firstIndex(of: "=") {
                attached = String(token[token.index(after: eq)...])
                token = String(token[..<eq])
            }

            // Flags
            if token.hasPrefix("-") {
                if attached == nil, token.hasPrefix("-X") && !token.hasPrefix("--") && token.count > 2 {
                    result.method = String(token.dropFirst(2)).uppercased()
                    index += 1
                    continue
                }
                if attached == nil, token.hasPrefix("-d") && !token.hasPrefix("--") && token.count > 2 && !token.hasPrefix("-H") {
                    result.body = String(token.dropFirst(2))
                    if result.method == "GET" { result.method = "POST" }
                    index += 1
                    continue
                }
                if valueOptions.contains(token) {
                    if let attached = attached {
                        applyValueOption(token, attached, to: &result)
                        index += 1
                        continue
                    }
                    if index + 1 < tokens.count {
                        applyValueOption(token, tokens[index + 1], to: &result)
                        index += 2
                        continue
                    }
                }
                if token == "-k" || token == "--insecure" {
                    result.insecure = true
                }
                index += 1
                continue
            }

            // First non-flag argument: the URL (skipping the leading "curl").
            if result.url.isEmpty && token != "curl" {
                result.url = token
            }
            index += 1
        }

        return result
    }

    private static func applyValueOption(_ option: String, _ value: String, to result: inout ParsedCurl) {
        switch option {
        case "-X", "--request":
            result.method = value.uppercased()
        case "-H", "--header":
            if let colon = value.firstIndex(of: ":") {
                let key = String(value[..<colon]).trimmingCharacters(in: .whitespaces)
                let headerValue = String(value[value.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                result.headers.append((key, headerValue))
            }
        case "-d", "--data", "--data-raw", "--data-binary", "--data-urlencode":
            result.body = value
            if result.method == "GET" { result.method = "POST" }
        default:
            break
        }
    }

    static func generateSwift(_ curl: ParsedCurl) -> String {
        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("")
        lines.append("let url = URL(string: \"\(curl.url)\")!")
        lines.append("var request = URLRequest(url: url)")
        lines.append("request.httpMethod = \"\(curl.method)\"")
        
        for (key, value) in curl.headers {
            lines.append("request.setValue(\"\(value)\", forHTTPHeaderField: \"\(key)\")")
        }
        
        if !curl.body.isEmpty {
            lines.append("let body = \"\(curl.body.replacingOccurrences(of: "\"", with: "\\\""))\"")
            lines.append("request.httpBody = body.data(using: .utf8)")
        }
        
        lines.append("")
        lines.append("let task = URLSession.shared.dataTask(with: request) { data, response, error in")
        lines.append("    guard let data = data else { return }")
        lines.append("    print(String(data: data, encoding: .utf8)!)")
        lines.append("}")
        lines.append("task.resume()")
        
        return lines.joined(separator: "\n")
    }
    
    static func generatePython(_ curl: ParsedCurl) -> String {
        var lines: [String] = []
        lines.append("import requests")
        lines.append("")
        
        let headers = curl.headers.map { "    \"\($0.0)\": \"\($0.1)\"" }.joined(separator: ",\n")
        if !headers.isEmpty {
            lines.append("headers = {")
            lines.append(headers)
            lines.append("}")
        }
        
        var params = curl.headers.isEmpty ? "headers={}" : "headers=headers"
        if !curl.body.isEmpty {
            params += ",\n    data=\"\(curl.body.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        
        lines.append("")
        lines.append("response = requests.\(curl.method.lowercased())(")
        lines.append("    \"\(curl.url)\",")
        lines.append("    \(params)")
        lines.append(")")
        lines.append("print(response.text)")
        
        return lines.joined(separator: "\n")
    }
    
    static func generateJavaScript(_ curl: ParsedCurl) -> String {
        var lines: [String] = []
        lines.append("fetch(\"\(curl.url)\", {")
        lines.append("    method: \"\(curl.method)\",")
        
        if !curl.headers.isEmpty {
            lines.append("    headers: {")
            for (key, value) in curl.headers {
                lines.append("        \"\(key)\": \"\(value)\",")
            }
            lines.append("    },")
        }
        
        if !curl.body.isEmpty {
            let trimmed = curl.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                // A JSON body is valid JavaScript literal syntax as-is.
                lines.append("    body: \(curl.body)")
            } else {
                let escaped = curl.body
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                lines.append("    body: \"\(escaped)\"")
            }
        }
        
        lines.append("})")
        lines.append(".then(response => response.text())")
        lines.append(".then(data => console.log(data))")
        lines.append(".catch(error => console.error(error));")
        
        return lines.joined(separator: "\n")
    }
    
    static func generateGo(_ curl: ParsedCurl) -> String {
        var lines: [String] = []
        lines.append("package main")
        lines.append("")
        lines.append("import (")
        lines.append("    \"fmt\"")
        lines.append("    \"io\"")
        lines.append("    \"net/http\"")
        if !curl.body.isEmpty {
            lines.append("    \"strings\"")
        }
        lines.append(")")
        lines.append("")
        lines.append("func main() {")
        
        if !curl.body.isEmpty {
            lines.append("    body := strings.NewReader(`\(curl.body)`)")
            lines.append("    req, _ := http.NewRequest(\"\(curl.method)\", \"\(curl.url)\", body)")
        } else {
            lines.append("    req, _ := http.NewRequest(\"\(curl.method)\", \"\(curl.url)\", nil)")
        }
        
        for (key, value) in curl.headers {
            lines.append("    req.Header.Set(\"\(key)\", \"\(value)\")")
        }
        
        lines.append("")
        lines.append("    resp, _ := http.DefaultClient.Do(req)")
        lines.append("    defer resp.Body.Close()")
        lines.append("    data, _ := io.ReadAll(resp.Body)")
        lines.append("    fmt.Println(string(data))")
        lines.append("}")
        
        return lines.joined(separator: "\n")
    }
    
    static func generatePHP(_ curl: ParsedCurl) -> String {
        var lines: [String] = []
        lines.append("<?php")
        lines.append("")
        lines.append("$ch = curl_init();")
        lines.append("curl_setopt($ch, CURLOPT_URL, \"\(curl.url)\");")
        lines.append("curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);")
        lines.append("curl_setopt($ch, CURLOPT_CUSTOMREQUEST, \"\(curl.method)\");")
        
        if !curl.headers.isEmpty {
            let headers = curl.headers.map { h in "\"\(h.0): \(h.1)\"" }.joined(separator: ", ")
            lines.append("curl_setopt($ch, CURLOPT_HTTPHEADER, [\(headers)]);")
        }
        
        if !curl.body.isEmpty {
            lines.append("curl_setopt($ch, CURLOPT_POSTFIELDS, \"\(curl.body.replacingOccurrences(of: "\"", with: "\\\""))\");")
        }
        
        if curl.insecure {
            lines.append("curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);")
        }
        
        lines.append("")
        lines.append("$response = curl_exec($ch);")
        lines.append("curl_close($ch);")
        lines.append("echo $response;")
        
        return lines.joined(separator: "\n")
    }
    
    static func generateJava(_ curl: ParsedCurl) -> String {
        var lines: [String] = []
        lines.append("import java.net.http.HttpClient;")
        lines.append("import java.net.http.HttpRequest;")
        lines.append("import java.net.http.HttpResponse;")
        lines.append("import java.net.URI;")
        lines.append("")
        lines.append("public class Main {")
        lines.append("    public static void main(String[] args) throws Exception {")
        lines.append("        var client = HttpClient.newHttpClient();")
        
        var requestBuilder = "        var request = HttpRequest.newBuilder()"
        requestBuilder += "\n            .uri(URI.create(\"\(curl.url)\"))"
        requestBuilder += "\n            .method(\"\(curl.method)\", "
        
        if !curl.body.isEmpty {
            requestBuilder += "HttpRequest.BodyPublishers.ofString(\"\(curl.body.replacingOccurrences(of: "\"", with: "\\\""))\"))"
        } else {
            requestBuilder += "HttpRequest.BodyPublishers.noBody())"
        }
        
        for (key, value) in curl.headers {
            requestBuilder += "\n            .header(\"\(key)\", \"\(value)\")"
        }
        
        requestBuilder += ";"
        lines.append(requestBuilder)
        lines.append("")
        lines.append("        var response = client.send(request, HttpResponse.BodyHandlers.ofString());")
        lines.append("        System.out.println(response.body());")
        lines.append("    }")
        lines.append("}")
        
        return lines.joined(separator: "\n")
    }
}
