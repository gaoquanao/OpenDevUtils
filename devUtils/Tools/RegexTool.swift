import SwiftUI

struct RegexTool: Tool {
    let id = "regex"
    let name = "Regex"
    let icon = "text.magnifyingglass"
    let category: ToolCategory = .text
    
    @State private var pattern = ""
    @State private var testString = ""
    @State private var matches: [RegexMatch] = []
    @State private var errorMessage: String?
    @State private var noticeMessage: String?
    @State private var options: Set<RegexOption> = [.caseInsensitive]
    @State private var requestVersion = 0
    @ObservedObject private var lang = LanguageManager.shared
    
    private static let maxInputSize = RegexRunner.defaultMaxInputBytes
    private static let maxMatches = RegexRunner.defaultMaxMatches
    private static let matchDeadline: TimeInterval = 2.0
    
    struct RegexMatch: Identifiable {
        let id = UUID()
        let range: NSRange
        let text: String
        let groups: [String]
    }
    
    enum RegexOption: String, CaseIterable, Identifiable {
        case caseInsensitive = "i"
        case multiline = "m"
        case dotMatchesLineSeparators = "s"
        
        var id: String { rawValue }
        
        var flag: NSRegularExpression.Options {
            switch self {
            case .caseInsensitive: return .caseInsensitive
            case .multiline: return .anchorsMatchLines
            case .dotMatchesLineSeparators: return .dotMatchesLineSeparators
            }
        }
        
        func label(for lang: AppLanguage) -> String {
            switch self {
            case .caseInsensitive:
                switch lang {
                case .en: return "i (Case Insensitive)"
                case .zh: return "i (忽略大小写)"
                case .ja: return "i (大文字小文字を無視)"
                case .ko: return "i (대소문자 무시)"
                }
            case .multiline:
                switch lang {
                case .en: return "m (Multiline)"
                case .zh: return "m (多行模式)"
                case .ja: return "m (複数行)"
                case .ko: return "m (여러 줄)"
                }
            case .dotMatchesLineSeparators:
                switch lang {
                case .en: return "s (Dot All)"
                case .zh: return "s (点匹配换行)"
                case .ja: return "s (ドットALL)"
                case .ko: return "s (점 전체)"
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 16) {
                patternSection
                optionsSection
                testStringSection
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
            Text(L(.regularExpression))
                .font(.title2.bold())
            Spacer()
            Button(L(.clear)) {
                requestVersion += 1
                pattern = ""
                testString = ""
                matches = []
                errorMessage = nil
                noticeMessage = nil
            }
        }
        .padding(.vertical, 8)
    }
    
    private var patternSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.pattern)).font(.headline)
            HStack {
                TextField(L(.enterRegexPattern), text: $pattern)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { executeRegex() }
                
                Button(L(.test)) { executeRegex() }
                    .buttonStyle(.borderedProminent)
            }
            if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            if let notice = noticeMessage {
                Label(notice, systemImage: "info.circle")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L(.options)).font(.headline)
            HStack(spacing: 12) {
                ForEach(RegexOption.allCases) { opt in
                    Toggle(opt.label(for: lang.language), isOn: Binding(
                        get: { options.contains(opt) },
                        set: { if $0 { options.insert(opt) } else { options.remove(opt) } }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
    
    private var testStringSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.testString)).font(.headline)
                Spacer()
                Button(L(.paste)) {
                    testString = PasteboardHelper.readString()
                    executeRegex()
                }
            }
            TextEditor(text: $testString)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.visible)
                .disableSmartQuotes()
                .border(.quaternary, width: 1)
                .frame(minHeight: 80, maxHeight: .infinity)
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L(.matches)).font(.headline)
                Spacer()
                if !matches.isEmpty {
                    Text("\(matches.count) \(L(.match))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(L(.copyAll)) {
                    let all = matches.map { $0.text }.joined(separator: "\n")
                    PasteboardHelper.writeString(all)
                }
                .disabled(matches.isEmpty)
            }
            
            if matches.isEmpty {
                Text(L(.noMatchesFound))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(matches) { match in
                            HStack {
                                Text(match.text)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .cornerRadius(4)
                                if !match.groups.isEmpty {
                                    Text("groups: \(match.groups.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)
                .border(.quaternary, width: 1)
            }
        }
    }
    
    private func executeRegex() {
        errorMessage = nil
        noticeMessage = nil
        matches = []
        
        guard !pattern.isEmpty else {
            errorMessage = L(.enterRegexPattern)
            return
        }
        
        guard !testString.isEmpty else { return }
        
        // Size guard for ReDoS protection (also enforced inside RegexRunner).
        guard testString.utf8.count < Self.maxInputSize else {
            errorMessage = L(.inputTooLarge, testString.utf8.count / 1_000_000, 10)
            return
        }
        
        let nsOptionsInt = options.reduce(0) { $0 | Int($1.flag.rawValue) }
        let nsOptions = NSRegularExpression.Options(rawValue: UInt(nsOptionsInt))
        let runPattern = pattern
        let input = testString
        
        requestVersion += 1
        let version = requestVersion
        
        // Run on a background queue so a pathological pattern can't freeze
        // the UI; discard stale results via requestVersion.
        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = Date().addingTimeInterval(Self.matchDeadline)
            let result = RegexRunner.run(pattern: runPattern,
                                         input: input,
                                         options: nsOptions,
                                         maxMatches: Self.maxMatches,
                                         maxInputBytes: Self.maxInputSize,
                                         deadline: deadline)
            
            DispatchQueue.main.async {
                guard version == self.requestVersion else { return }
                
                switch result.status {
                case .invalidPattern:
                    self.errorMessage = L(.invalidRegexPattern)
                    return
                case .tooLarge:
                    self.errorMessage = L(.inputTooLarge, input.utf8.count / 1_000_000, 10)
                    return
                case .success:
                    break
                }
                
                self.matches = result.matches.map {
                    RegexMatch(range: $0.range, text: $0.text, groups: $0.groups)
                }
                
                if result.timedOut {
                    self.errorMessage = L(.regexTooSlow)
                } else if result.truncated {
                    self.noticeMessage = L(.tooManyMatches, result.matches.count)
                }
                // No matches is not an error — resultsSection shows the
                // placeholder for that.
            }
        }
    }
}
