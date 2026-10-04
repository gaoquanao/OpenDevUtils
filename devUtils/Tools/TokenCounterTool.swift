import SwiftUI

struct TokenCounterTool: Tool {
    let id = "tokenCounter"
    let name = "Token Counter"
    let icon = "character.bubble"
    let category: ToolCategory = .text
    
    @State private var input = ""
    @State private var selectedModel: ModelType = .gpt4
    @State private var stats = TokenStats(text: "", charsPerToken: ModelType.gpt4.charsPerToken)
    @State private var pendingRecompute: DispatchWorkItem?
    
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

    /// Debounced recompute: without it every keystroke re-scanned the whole
    /// (potentially multi-MB) input synchronously.
    private func scheduleRecompute() {
        pendingRecompute?.cancel()
        let item = DispatchWorkItem { [self] in
            stats = TokenStats(text: input, charsPerToken: selectedModel.charsPerToken)
        }
        pendingRecompute = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
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
                .onChange(of: input) { _ in scheduleRecompute() }
        }
    }
}

struct TokenStats {
    let text: String
    let charsPerToken: Double

    let characters: Int
    let bytes: Int
    let words: Int
    let lines: Int
    /// Han characters only (UI label "Chinese characters").
    let chineseChars: Int
    /// Han + Hiragana + Katakana + Hangul — the set used for token estimation
    /// AND removed from the remaining text (previously the two sets differed,
    /// so pure Japanese/Korean input estimated "0 ~ 0 tokens").
    let cjkChars: Int
    let englishWords: Int
    let punctuation: Int
    let estimatedTokens: Int
    let estimatedTokensMax: Int

    init(text: String, charsPerToken: Double) {
        self.text = text
        self.charsPerToken = charsPerToken
        self.characters = text.count
        self.bytes = text.utf8.count

        guard !text.isEmpty else {
            words = 0
            lines = 0
            chineseChars = 0
            cjkChars = 0
            englishWords = 0
            punctuation = 0
            estimatedTokens = 0
            estimatedTokensMax = 0
            return
        }

        words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        lines = trimmed.isEmpty ? 0 : trimmed.components(separatedBy: "\n").count

        var han = 0
        var cjk = 0
        var punct = 0
        for scalar in text.unicodeScalars {
            let value = scalar.value
            let isHan = (value >= 0x4E00 && value <= 0x9FFF)
                || (value >= 0x3400 && value <= 0x4DBF)
                || (value >= 0x20000 && value <= 0x2A6DF)
            let isKanaOrHangul = (value >= 0x3040 && value <= 0x30FF)   // Hiragana + Katakana
                || (value >= 0xAC00 && value <= 0xD7AF)                 // Hangul syllables
                || (value >= 0x1100 && value <= 0x11FF)                 // Hangul jamo
                || (value >= 0x3130 && value <= 0x318F)                 // Hangul compat jamo
            if isHan {
                han += 1
                cjk += 1
            } else if isKanaOrHangul {
                cjk += 1
            }
            if CharacterSet.punctuationCharacters.contains(scalar) {
                punct += 1
            }
        }
        chineseChars = han
        cjkChars = cjk
        punctuation = punct

        englishWords = text.components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.range(of: "[a-zA-Z]", options: .regularExpression) != nil }.count

        // Single removal pass for both estimates (was two regex passes each).
        let remainingCount = text.replacingOccurrences(
            of: "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\p{Hangul}]",
            with: "",
            options: .regularExpression
        ).count

        estimatedTokens = cjk * 2 + Int(ceil(Double(remainingCount) / charsPerToken))
        let maxCharsPerToken = Swift.max(charsPerToken - 0.5, 0.5)
        estimatedTokensMax = cjk * 3 + Int(ceil(Double(remainingCount) / maxCharsPerToken))
    }
}
