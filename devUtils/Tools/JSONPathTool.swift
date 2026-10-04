import SwiftUI

struct JSONPathTool: Tool {
    let id = "jsonPath"
    let name = "JSONPath"
    let icon = "magnifyingglass"
    let category: ToolCategory = .json
    
    @State private var jsonInput = ""
    @State private var jsonpath = ""
    @State private var resultCount = 0
    @State private var errorMessage: String?
    @State private var formattedOutput = ""
    @State private var outputPreview = JSONProcessor.Preview(display: "", truncated: false, totalCharacters: 0)
    @State private var isProcessing = false
    @State private var requestVersion = 0
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
            
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            }
            
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
                    jsonInput = PasteboardHelper.readString()
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
                
                if resultCount > 0 {
                    Text("\(resultCount) \(L(.resultsCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(L(.copy)) {
                    PasteboardHelper.writeString(formattedOutput)
                }
                .disabled(formattedOutput.isEmpty)
            }
            
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            }
            
            ScrollView {
                Text(outputPreview.display)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .border(.quaternary, width: 1)
            .frame(minHeight: 100, maxHeight: .infinity)
            
            if outputPreview.truncated {
                Label(L(.outputTruncated, outputPreview.display.count, outputPreview.totalCharacters),
                      systemImage: "scissors")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    /// Parsing + evaluation + formatting happen off the main thread so large
    /// documents don't freeze the UI; stale runs are dropped.
    private func executeQuery() {
        errorMessage = nil
        resultCount = 0
        formattedOutput = ""
        outputPreview = JSONProcessor.Preview(display: "", truncated: false, totalCharacters: 0)
        requestVersion += 1
        let version = requestVersion
        let inputSnapshot = jsonInput
        let pathSnapshot = jsonpath
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome: Result<(text: String, count: Int), JSONProcessor.Failure> =
                JSONProcessor.query(inputSnapshot, path: pathSnapshot).flatMap { matched in
                    if matched.isEmpty { return .success(("", 0)) }
                    do {
                        return .success((try JSONProcessor.formatQueryResults(matched), matched.count))
                    } catch {
                        return .failure(.invalid(error.localizedDescription))
                    }
                }
            
            DispatchQueue.main.async {
                guard version == requestVersion else { return }
                isProcessing = false
                switch outcome {
                case .success(let value):
                    resultCount = value.count
                    if value.text.isEmpty {
                        formattedOutput = L(.noResults)
                        outputPreview = JSONProcessor.preview(L(.noResults))
                    } else {
                        formattedOutput = value.text
                        outputPreview = JSONProcessor.preview(value.text)
                    }
                case .failure(let failure):
                    errorMessage = failure.message
                }
            }
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
