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
                curlCommand = NSPasteboard.general.string(forType: .string) ?? ""
                convert()
            }
            Button(L(.clear)) {
                curlCommand = ""
                outputCode = ""
                parsedParts = nil
            }
        }
        .padding(.vertical, 8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.curlInput)).font(.headline)
            TextEditor(text: $curlCommand)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minHeight: 120)
                .onChange(of: curlCommand) { _ in convert() }
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
                Button(L(.copy)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(outputCode, forType: .string)
                }
                .disabled(outputCode.isEmpty)
            }
            SyntaxHighlightedCode(code: outputCode, language: selectedLanguage.rawValue)
                .frame(minHeight: 150, maxHeight: .infinity)
        }
    }
    
    private func convert() {
        let parsed = parseCurl(curlCommand)
        parsedParts = parsed
        
        switch selectedLanguage {
        case .swift: outputCode = generateSwift(parsed)
        case .python: outputCode = generatePython(parsed)
        case .javascript: outputCode = generateJavaScript(parsed)
        case .go: outputCode = generateGo(parsed)
        case .php: outputCode = generatePHP(parsed)
        case .java: outputCode = generateJava(parsed)
        }
    }
    
    private func parseCurl(_ command: String) -> ParsedCurl {
        var result = ParsedCurl()
        let cmd = command.replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        
        // Extract URL
        if let urlRange = cmd.range(of: "'[^']*'|\"[^\"]*\"", options: .regularExpression) {
            var url = String(cmd[urlRange])
            url = String(url.dropFirst().dropLast())
            result.url = url
        }
        
        // Extract method
        if cmd.contains("-X ") || cmd.contains("--request ") {
            if let methodRange = cmd.range(of: "-X\\s+(\\w+)", options: .regularExpression) {
                result.method = String(cmd[methodRange]).replacingOccurrences(of: "-X\\s+", with: "", options: .regularExpression)
            }
        }
        
        // Extract headers
        let headerPattern = "-H\\s+['\"]([^'\"]+)['\"]"
        if let regex = try? NSRegularExpression(pattern: headerPattern) {
            let range = NSRange(cmd.startIndex..., in: cmd)
            for match in regex.matches(in: cmd, range: range) {
                if let headerRange = Range(match.range(at: 1), in: cmd) {
                    let header = String(cmd[headerRange])
                    if let colonIndex = header.firstIndex(of: ":") {
                        let key = String(header[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(header[header.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        result.headers.append((key, value))
                    }
                }
            }
        }
        
        // Extract body
        if cmd.contains("-d ") || cmd.contains("--data ") {
            if let bodyRange = cmd.range(of: "-d\\s+['\"]([^'\"]*)['\"]", options: .regularExpression) {
                let body = String(cmd[bodyRange])
                    .replacingOccurrences(of: "-d\\s+['\"]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "['\"]$", with: "", options: .regularExpression)
                result.body = body
                if result.method == "GET" { result.method = "POST" }
            }
        }
        
        // Check for -k
        if cmd.contains("-k ") || cmd.contains("--insecure") {
            result.insecure = true
        }
        
        return result
    }
    
    private func generateSwift(_ curl: ParsedCurl) -> String {
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
    
    private func generatePython(_ curl: ParsedCurl) -> String {
        var lines: [String] = []
        lines.append("import requests")
        lines.append("")
        
        let headers = curl.headers.map { "    \"\($0.0)\": \"\($0.1)\"" }.joined(separator: ",\n")
        if !headers.isEmpty {
            lines.append("headers = {")
            lines.append(headers)
            lines.append("}")
        }
        
        var params = "headers=headers" + (curl.headers.isEmpty ? "={}" : "")
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
    
    private func generateJavaScript(_ curl: ParsedCurl) -> String {
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
            lines.append("    body: JSON.stringify(\(curl.body))")
        }
        
        lines.append("})")
        lines.append(".then(response => response.text())")
        lines.append(".then(data => console.log(data))")
        lines.append(".catch(error => console.error(error));")
        
        return lines.joined(separator: "\n")
    }
    
    private func generateGo(_ curl: ParsedCurl) -> String {
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
    
    private func generatePHP(_ curl: ParsedCurl) -> String {
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
    
    private func generateJava(_ curl: ParsedCurl) -> String {
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
