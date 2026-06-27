import SwiftUI

// MARK: - Tool Metadata Registry

struct ToolMeta: Identifiable {
    let id: ToolID
    let icon: String
    let nameKey: LocalizedString
    let category: ToolCategory
    
    var name: String { L(nameKey) }
}

extension ToolMeta {
    static let all: [ToolMeta] = [
        // Encoding
        ToolMeta(id: .base64,          icon: "lock.fill",               nameKey: .toolBase64,          category: .encoding),
        ToolMeta(id: .base64Image,     icon: "photo",                   nameKey: .toolBase64Image,     category: .encoding),
        ToolMeta(id: .hash,            icon: "number",                  nameKey: .toolHash,            category: .encoding),
        ToolMeta(id: .urlCodec,        icon: "link",                    nameKey: .toolUrlEncode,       category: .encoding),
        // Text
        ToolMeta(id: .sqlFormatter,    icon: "terminal",                nameKey: .toolSqlFormatter,    category: .text),
        ToolMeta(id: .textDiff,        icon: "doc.on.doc",              nameKey: .toolTextDiff,        category: .text),
        ToolMeta(id: .batchText,       icon: "text.badge.checkmark",    nameKey: .toolBatchText,       category: .text),
        ToolMeta(id: .tokenCounter,    icon: "character.bubble",        nameKey: .toolTokenCounter,    category: .text),
        ToolMeta(id: .regex,           icon: "text.magnifyingglass",    nameKey: .toolRegex,           category: .text),
        // JSON / YAML
        ToolMeta(id: .jsonEditor,      icon: "doc.text.fill",           nameKey: .toolJsonEditor,      category: .json),
        ToolMeta(id: .jsonPath,        icon: "magnifyingglass",         nameKey: .toolJsonPath,        category: .json),
        ToolMeta(id: .yamlJson,        icon: "arrow.left.arrow.right",  nameKey: .toolYamlJson,        category: .json),
        ToolMeta(id: .jwtDebugger,     icon: "key",                     nameKey: .toolJwtDebugger,     category: .json),
        // Web / Dev
        ToolMeta(id: .htmlPreview,     icon: "globe",                   nameKey: .toolHtmlPreview,     category: .webDev),
        ToolMeta(id: .markdownPreview, icon: "doc.richtext",            nameKey: .toolMarkdownPreview, category: .webDev),
        ToolMeta(id: .qrCode,          icon: "qrcode",                  nameKey: .toolQrCode,          category: .webDev),
        ToolMeta(id: .curlConverter,   icon: "arrow.triangle.branch",   nameKey: .toolCurlConverter,   category: .webDev),
        ToolMeta(id: .cronParser,      icon: "clock",                   nameKey: .toolCronParser,      category: .webDev),
        ToolMeta(id: .timestamp,       icon: "calendar",                nameKey: .toolTimestamp,       category: .webDev),
    ]
    
    static let groupedByCategory: [(category: ToolCategory, tools: [ToolMeta])] = {
        ToolCategory.allCases.map { cat in
            (cat, all.filter { $0.category == cat })
        }.filter { !$0.tools.isEmpty }
    }()
}

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
            ForEach(ToolMeta.groupedByCategory, id: \.category) { group in
                Section(group.category.localizedTitle) {
                    ForEach(group.tools) { tool in
                        Label(tool.name, systemImage: tool.icon)
                            .tag(tool.id)
                    }
                }
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
