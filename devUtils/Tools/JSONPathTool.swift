import SwiftUI

struct JSONPathTool: Tool {
    let id = "jsonPath"
    let name = "JSONPath"
    let icon = "magnifyingglass"
    let category: ToolCategory = .json
    
    @State private var jsonInput = ""
    @State private var jsonpath = ""
    @State private var results: [JSON] = []
    @State private var errorMessage: String?
    @State private var formattedOutput = ""
    @ObservedObject private var lang = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            VStack(spacing: 16) {
                jsonInputSection
                jsonpathInputSection
                resultsSection
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var header: some View {
        HStack {
            Text(L(.jsonpathQuery))
                .font(.title2.bold())
            
            Spacer()
            
            Button(L(.loadSample)) {
                loadSampleJSON()
            }
            
            Button(L(.execute)) {
                executeQuery()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }
    
    private var jsonInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.jsonInput))
                    .font(.headline)
                Spacer()
                Button(L(.paste)) {
                    jsonInput = NSPasteboard.general.string(forType: .string) ?? ""
                }
            }
            
            TextEditor(text: $jsonInput)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minHeight: 100, maxHeight: .infinity)
        }
    }
    
    private var jsonpathInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.jsonpathExpression))
                    .font(.headline)
                Spacer()
                
                Menu {
                    examplesMenu
                } label: {
                    Label(L(.examples), systemImage: "lightbulb")
                }
            }
            
            HStack {
                TextField("e.g. $.store.book[*].title", text: $jsonpath)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                
                Button(L(.execute)) {
                    executeQuery()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var examplesMenu: some View {
        Group {
            Button("$.store.book[*].title") {
                jsonpath = "$.store.book[*].title"
            }
            Button("$.store.book[?(@.price < 10)]") {
                jsonpath = "$.store.book[?(@.price < 10)]"
            }
            Button("$.store.book[0]") {
                jsonpath = "$.store.book[0]"
            }
            Button("$[*]") {
                jsonpath = "$[*]"
            }
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.results))
                    .font(.headline)
                Spacer()
                
                if !results.isEmpty {
                    Text("\(results.count) \(L(.resultsCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(L(.copy)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(formattedOutput, forType: .string)
                }
                .disabled(results.isEmpty)
            }
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.vertical, 4)
            }
            
            TextEditor(text: .constant(formattedOutput))
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .textSelection(.enabled)
                .border(.quaternary, width: 1)
                .frame(minHeight: 100, maxHeight: .infinity)
        }
    }
    
    private func executeQuery() {
        errorMessage = nil
        results = []
        formattedOutput = ""
        
        guard let jsonData = jsonInput.data(using: .utf8) else {
            errorMessage = L(.invalidJSON)
            return
        }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) else {
            errorMessage = L(.invalidJSON)
            return
        }
        
        let engine = JSONPathEngine()
        do {
            results = try engine.evaluate(json: jsonObject, path: jsonpath)
            
            if results.isEmpty {
                formattedOutput = L(.noResults)
            } else {
                let rawValues = results.map { $0.value }
                let outputData = try JSONSerialization.data(withJSONObject: rawValues.count == 1 ? rawValues[0] : rawValues, options: [.prettyPrinted, .sortedKeys])
                formattedOutput = String(data: outputData, encoding: .utf8) ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadSampleJSON() {
        jsonInput = """
        {
          "store": {
            "book": [
              {
                "category": "reference",
                "author": "Nigel Rees",
                "title": "Sayings of the Century",
                "price": 8.95
              },
              {
                "category": "fiction",
                "author": "Evelyn Waugh",
                "title": "Sword of Honour",
                "price": 12.99
              },
              {
                "category": "fiction",
                "author": "Herman Melville",
                "title": "Moby Dick",
                "price": 8.99
              }
            ],
            "bicycle": {
              "color": "red",
              "price": 19.95
            }
          }
        }
        """
        jsonpath = "$.store.book[*].title"
    }
}
