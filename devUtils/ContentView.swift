import SwiftUI

struct ContentView: View {
    @State private var selectedToolID: ToolID? = .base64
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                languageMenu
            }
            ToolbarItem(placement: .automatic) {
                appearanceMenu
            }
        }
    }
    
    private var languageMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    languageManager.language = lang
                } label: {
                    HStack {
                        Text(lang.rawValue)
                        if languageManager.language == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .help(LocalizedString.language.text(for: languageManager.language))
    }
    
    private var appearanceMenu: some View {
        Menu {
            ForEach(AppAppearance.allCases, id: \.self) { mode in
                Button {
                    appearanceManager.appearance = mode
                } label: {
                    HStack {
                        Text(mode.rawValue)
                        if appearanceManager.appearance == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: appearanceManager.appearance == .system ? "circle.lefthalf.filled" :
                    appearanceManager.appearance == .light ? "sun.max.fill" : "moon.fill")
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .help(LocalizedString.appearance.text(for: languageManager.language))
    }
    
    private var sidebar: some View {
        List(selection: $selectedToolID) {
            Section("Encoding") {
                Label("Base64", systemImage: "lock.fill")
                    .tag(ToolID.base64)
                Label("Base64 Image", systemImage: "photo")
                    .tag(ToolID.base64Image)
                Label("Hash", systemImage: "number")
                    .tag(ToolID.hash)
                Label("URL Encode", systemImage: "link")
                    .tag(ToolID.urlCodec)
                Label("SQL Formatter", systemImage: "terminal")
                    .tag(ToolID.sqlFormatter)
            }
            Section("Text") {
                Label("Text Diff", systemImage: "doc.on.doc")
                    .tag(ToolID.textDiff)
                Label("Batch Text", systemImage: "text.badge.checkmark")
                    .tag(ToolID.batchText)
                Label("Token Counter", systemImage: "character.bubble")
                    .tag(ToolID.tokenCounter)
                Label("Regex", systemImage: "text.magnifyingglass")
                    .tag(ToolID.regex)
            }
            Section("JSON / YAML") {
                Label("JSON Editor", systemImage: "doc.text.fill")
                    .tag(ToolID.jsonEditor)
                Label("JSONPath", systemImage: "magnifyingglass")
                    .tag(ToolID.jsonPath)
                Label("YAML ↔ JSON", systemImage: "arrow.left.arrow.right")
                    .tag(ToolID.yamlJson)
                Label("JWT Debugger", systemImage: "key")
                    .tag(ToolID.jwtDebugger)
            }
            Section("Web / Dev") {
                Label("HTML Preview", systemImage: "globe")
                    .tag(ToolID.htmlPreview)
                Label("Markdown Preview", systemImage: "doc.richtext")
                    .tag(ToolID.markdownPreview)
                Label("QR Code", systemImage: "qrcode")
                    .tag(ToolID.qrCode)
                Label("cURL Converter", systemImage: "arrow.triangle.branch")
                    .tag(ToolID.curlConverter)
                Label("Cron Parser", systemImage: "clock")
                    .tag(ToolID.cronParser)
                Label("Timestamp", systemImage: "calendar")
                    .tag(ToolID.timestamp)
            }
        }
        .navigationTitle("OpenDevUtils")
        .listStyle(.sidebar)
    }
    
    @ViewBuilder
    private var detail: some View {
        switch selectedToolID {
        case .base64:
            Base64Tool()
        case .base64Image:
            Base64ImageTool()
        case .hash:
            HashTool()
        case .urlCodec:
            URLTool()
        case .sqlFormatter:
            SQLFormatterTool()
        case .textDiff:
            TextDifferTool()
        case .batchText:
            BatchTextTool()
        case .tokenCounter:
            TokenCounterTool()
        case .regex:
            RegexTool()
        case .jsonEditor:
            JSONEditorTool()
        case .jsonPath:
            JSONPathTool()
        case .yamlJson:
            YAMLTool()
        case .jwtDebugger:
            JWTDebuggerTool()
        case .htmlPreview:
            HTMLPreviewTool()
        case .markdownPreview:
            MarkdownPreviewTool()
        case .qrCode:
            QRCodeTool()
        case .curlConverter:
            CurlConverterTool()
        case .cronParser:
            CronTool()
        case .timestamp:
            TimestampTool()
        case .none:
            Text(LocalizedString.selectTool.text(for: languageManager.language))
                .foregroundStyle(.secondary)
        }
    }
}

enum ToolID: String, Hashable {
    case base64
    case base64Image
    case hash
    case urlCodec
    case sqlFormatter
    case textDiff
    case batchText
    case tokenCounter
    case regex
    case jsonEditor
    case jsonPath
    case yamlJson
    case jwtDebugger
    case htmlPreview
    case markdownPreview
    case qrCode
    case curlConverter
    case cronParser
    case timestamp
}
