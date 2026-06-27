import SwiftUI

struct TokenCounterTool: Tool {
    let id = "tokenCounter"
    let name = "Token Counter"
    let icon = "character.bubble"
    let category: ToolCategory = .text
    
    @State private var input = ""
    @State private var selectedModel: ModelType = .gpt4
    @State private var stats = TokenStats(text: "", charsPerToken: ModelType.gpt4.charsPerToken)
    
    @ObservedObject private var lang = LanguageManager.shared
    
    enum ModelType: String, CaseIterable, Identifiable {
        case gpt4 = "GPT-4 / Claude"
        case gpt35 = "GPT-3.5"
        case local = "Local LLM"
        
        var id: String { rawValue }
        
        var charsPerToken: Double {
            switch self {
            case .gpt4: return 3.5
            case .gpt35: return 4.0
            case .local: return 3.0
            }
        }
        
        func label(for lang: AppLanguage) -> String {
            switch self {
            case .gpt4, .gpt35:
                return rawValue
            case .local:
                switch lang {
                case .en: return "Local LLM"
                case .zh: return "本地模型"
                case .ja: return "ローカルLLM"
                case .ko: return "로컬 LLM"
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                modelPicker
                statsSection
                inputSection
                Spacer(minLength: 0)
            }
            .padding(.top, 12)
            .onChange(of: selectedModel) { _ in recomputeStats() }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { recomputeStats() }
    }
    
    private func recomputeStats() {
        stats = TokenStats(text: input, charsPerToken: selectedModel.charsPerToken)
    }
    
    private var header: some View {
        HStack {
            Text(L(.tokenCounter))
                .font(.title2.bold())
            Spacer()
            Button(L(.paste)) {
                input = PasteboardHelper.readString()
            }
            Button(L(.clear)) { input = "" }
        }
        .padding(.vertical, 8)
    }
    
    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.model)).font(.headline)
            HStack(spacing: 12) {
                ForEach(ModelType.allCases) { model in
                    Button {
                        selectedModel = model
                    } label: {
                        Text(model.label(for: lang.language))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedModel == model ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            .foregroundColor(selectedModel == model ? .white : .primary)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                statCard(title: L(.tokenCount), value: "\(stats.estimatedTokens)", color: .blue)
                statCard(title: L(.charCount), value: "\(stats.characters)", color: .green)
                statCard(title: L(.wordCount), value: "\(stats.words)", color: .orange)
                statCard(title: L(.lineCount), value: "\(stats.lines)", color: .purple)
            }
            
            HStack(spacing: 16) {
                statCard(title: L(.byteCount), value: "\(stats.bytes) B", color: .red)
                statCard(title: L(.chineseChars), value: "\(stats.chineseChars)", color: .cyan)
                statCard(title: L(.englishWords), value: "\(stats.englishWords)", color: .mint)
                statCard(title: L(.punctuation), value: "\(stats.punctuation)", color: .indigo)
            }
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.input)).font(.headline)
                Spacer()
                if !input.isEmpty {
                    Text("\(stats.estimatedTokens) ~ \(stats.estimatedTokensMax) \(L(.tokens))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minHeight: 200, maxHeight: .infinity)
                .onChange(of: input) { _ in recomputeStats() }
        }
    }
}

struct TokenStats {
    let text: String
    let charsPerToken: Double
    
    var characters: Int { text.count }
    
    var bytes: Int { text.utf8.count }
    
    var words: Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    var lines: Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? 0 : trimmed.components(separatedBy: "\n").count
    }
    
    var chineseChars: Int {
        text.unicodeScalars.filter {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||
            ($0.value >= 0x20000 && $0.value <= 0x2A6DF)
        }.count
    }
    
    var englishWords: Int {
        text.components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.range(of: "[a-zA-Z]", options: .regularExpression) != nil }.count
    }
    
    var punctuation: Int {
        text.unicodeScalars.filter {
            CharacterSet.punctuationCharacters.contains($0)
        }.count
    }
    
    var estimatedTokens: Int {
        if text.isEmpty { return 0 }
        
        // Count Chinese characters separately (typically 1-2 tokens each)
        let chineseTokenCount = chineseChars * 2
        
        // Remaining text
        let remaining = text.replacingOccurrences(
            of: "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}]",
            with: "",
            options: .regularExpression
        )
        
        // Estimate tokens for remaining text
        let remainingTokens = Int(ceil(Double(remaining.count) / charsPerToken))
        
        return chineseTokenCount + remainingTokens
    }
    
    var estimatedTokensMax: Int {
        if text.isEmpty { return 0 }
        
        let chineseTokenCount = chineseChars * 3
        
        let remaining = text.replacingOccurrences(
            of: "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}]",
            with: "",
            options: .regularExpression
        )
        
        let remainingTokens = Int(ceil(Double(remaining.count) / (charsPerToken - 0.5)))
        
        return chineseTokenCount + remainingTokens
    }
}
