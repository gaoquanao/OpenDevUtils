import Foundation

enum LocalizedString {
    // App
    case appTitle
    case selectTool
    
    // Common
    case input
    case output
    case paste
    case copy
    case copyAll
    case clear
    case execute
    case convert
    case test
    case refresh
    case results
    case noResults
    case description
    case options
    
    // Base64
    case base64Title
    case encode
    case decode
    
    // Hash
    case hashGenerator
    case uppercase
    
    // URL
    case urlEncodeDecode
    case mode
    case type
    case urlComponent
    case fullUrl
    
    // Text Diff
    case textDiff
    case original
    case modified
    case compare
    case diffResult
    case ignoreCase
    case ignoreWhitespace
    case clickCompareToSeeDifferences
    
    // Regex
    case regularExpression
    case pattern
    case testString
    case matches
    case match
    case noMatchesFound
    case enterRegexPattern
    case invalidRegexPattern
    
    // Batch Text
    case batchText
    case removeDuplicates
    case sortLines
    case removeEmptyLines
    case trimWhitespace
    case prefixSuffix
    case prefixPlaceholder
    case suffixPlaceholder
    case batchReplace
    case findPlaceholder
    case replacePlaceholder
    
    // Token Counter
    case tokenCounter
    case model
    case tokenCount
    case charCount
    case wordCount
    case lineCount
    case byteCount
    case chineseChars
    case englishWords
    case punctuation
    case tokens
    
    // Base64 Image
    case base64Image
    case base64Input
    case base64ImageHint
    case saveImage
    case invalidBase64
    case invalidImage
    
    // JWT
    case jwtDebugger
    case jwtTokenInput
    case signature
    case invalidJWT
    
    // Markdown
    case markdownPreview
    case markdownInput
    
    // QR Code
    case qrCode
    case generate
    case scanQR
    case qrCodeInput
    
    // SQL Formatter
    case sqlFormatter
    case keywordCase
    
    // cURL Converter
    case curlConverter
    case curlInput
    
    // JSON Editor
    case jsonEditor
    case prettyPrint
    case minify
    case invalidJSON
    
    // JSONPath
    case jsonpathQuery
    case jsonInput
    case jsonpathExpression
    case loadSample
    case examples
    case resultsCount
    
    // YAML
    case yamlJsonConverter
    case yamlToJson
    case jsonToYaml
    case yamlInput
    case jsonOutput
    case yamlOutput
    
    // HTML Preview
    case htmlPreview
    case htmlInput
    case preview
    
    // Cron Parser
    case cronExpressionParser
    case cronExpression
    case nextRuns
    case minute
    case hour
    case day
    case month
    case weekday
    case loadExample
    
    // Timestamp
    case unixTimestampConverter
    case currentTime
    case timestampToDate
    case dateToTimestamp
    case enterTimestamp
    case enterDate
    case seconds
    case milliseconds
    case invalidDateFormat
    
    // Settings
    case appearance
    case language
    case system
    case light
    case dark
    
    // Sidebar sections
    case sectionEncoding
    case sectionText
    case sectionJsonYaml
    case sectionWebDev
    
    // Sidebar tool names
    case toolBase64
    case toolBase64Image
    case toolHash
    case toolUrlEncode
    case toolSqlFormatter
    case toolTextDiff
    case toolBatchText
    case toolTokenCounter
    case toolRegex
    case toolJsonEditor
    case toolJsonPath
    case toolYamlJson
    case toolJwtDebugger
    case toolHtmlPreview
    case toolMarkdownPreview
    case toolQrCode
    case toolCurlConverter
    case toolCronParser
    case toolTimestamp
    
    // JWT
    case jwtHeader
    case jwtPayload
    
    // Cron descriptions
    case cronFiveFieldsRequired
    case cronEveryMinute
    case cronEveryHour
    case cronEveryDay
    case cronEveryMonth
    case cronEveryWeekday
    case cronEveryMinutes
    case cronEveryHours
    case cronEveryDays
    case cronEveryMonths
    case cronEveryWeekdays
    case cronFromTo
    case cronAt
    case cronRuns
    case jsonTooLarge
    
    func text(for lang: AppLanguage) -> String {
        switch lang {
        case .en: return en
        case .zh: return zh
        case .ja: return ja
        case .ko: return ko
        }
    }
    
    func text(for lang: AppLanguage, arguments: [CVarArg] = []) -> String {
        let template = text(for: lang)
        guard !arguments.isEmpty else { return template }
        return String(format: template, arguments: arguments)
    }
    
    private var en: String {
        switch self {
        case .appTitle: return "OpenDevUtils"
        case .selectTool: return "Select a tool"
        case .input: return "Input"
        case .output: return "Output"
        case .paste: return "Paste"
        case .copy: return "Copy"
        case .copyAll: return "Copy All"
        case .clear: return "Clear"
        case .execute: return "Execute"
        case .convert: return "Convert"
        case .test: return "Test"
        case .refresh: return "Refresh"
        case .results: return "Results"
        case .noResults: return "No results"
        case .description: return "Description"
        case .options: return "Options"
        case .base64Title: return "Base64 Encoder/Decoder"
        case .encode: return "Encode"
        case .scanQR: return "Scan"
        case .hashGenerator: return "Hash Generator"
        case .uppercase: return "UPPERCASE"
        case .urlEncodeDecode: return "URL Encode / Decode"
        case .mode: return "Mode"
        case .type: return "Type"
        case .urlComponent: return "URL Component"
        case .fullUrl: return "Full URL"
        case .textDiff: return "Text Diff"
        case .original: return "Original"
        case .modified: return "Modified"
        case .compare: return "Compare"
        case .diffResult: return "Diff Result"
        case .ignoreCase: return "Ignore Case"
        case .ignoreWhitespace: return "Ignore Whitespace"
        case .clickCompareToSeeDifferences: return "Click Compare to see differences"
        case .regularExpression: return "Regular Expression"
        case .pattern: return "Pattern"
        case .testString: return "Test String"
        case .matches: return "Matches"
        case .match: return "match"
        case .noMatchesFound: return "No matches found"
        case .enterRegexPattern: return "Enter a regex pattern"
        case .invalidRegexPattern: return "Invalid regex pattern"
        case .batchText: return "Batch Text"
        case .removeDuplicates: return "Remove Duplicates"
        case .sortLines: return "Sort Lines"
        case .removeEmptyLines: return "Remove Empty Lines"
        case .trimWhitespace: return "Trim Whitespace"
        case .prefixSuffix: return "Prefix / Suffix"
        case .prefixPlaceholder: return "Prefix (e.g. http://)"
        case .suffixPlaceholder: return "Suffix (e.g. .html)"
        case .batchReplace: return "Batch Replace"
        case .findPlaceholder: return "Find"
        case .replacePlaceholder: return "Replace"
        case .tokenCounter: return "Token Counter"
        case .model: return "Model"
        case .tokenCount: return "Tokens"
        case .charCount: return "Characters"
        case .wordCount: return "Words"
        case .lineCount: return "Lines"
        case .byteCount: return "Bytes"
        case .chineseChars: return "Chinese"
        case .englishWords: return "English"
        case .punctuation: return "Punct."
        case .tokens: return "tokens"
        case .base64Image: return "Base64 Image"
        case .base64Input: return "Base64 Input"
        case .base64ImageHint: return "Paste Base64 encoded image data to preview"
        case .saveImage: return "Save Image"
        case .invalidBase64: return "Invalid Base64 data"
        case .invalidImage: return "Invalid image data"
        case .jwtDebugger: return "JWT Debugger"
        case .jwtTokenInput: return "JWT Token"
        case .signature: return "Signature"
        case .invalidJWT: return "Invalid JWT token"
        case .markdownPreview: return "Markdown Preview"
        case .markdownInput: return "Markdown Input"
        case .qrCode: return "QR Code"
        case .generate: return "Generate"
        case .decode: return "Decode"
        case .qrCodeInput: return "QR Code Content"
        case .sqlFormatter: return "SQL Formatter"
        case .keywordCase: return "Keyword Case"
        case .curlConverter: return "cURL Converter"
        case .curlInput: return "cURL Command"
        case .jsonEditor: return "JSON Editor"
        case .prettyPrint: return "Pretty Print"
        case .minify: return "Minify"
        case .invalidJSON: return "Invalid JSON"
        case .jsonpathQuery: return "JSONPath Query"
        case .jsonInput: return "JSON Input"
        case .jsonpathExpression: return "JSONPath Expression"
        case .loadSample: return "Load Sample"
        case .examples: return "Examples"
        case .resultsCount: return "results"
        case .yamlJsonConverter: return "YAML ↔ JSON Converter"
        case .yamlToJson: return "YAML → JSON"
        case .jsonToYaml: return "JSON → YAML"
        case .yamlInput: return "YAML Input"
        case .jsonOutput: return "JSON Output"
        case .yamlOutput: return "YAML Output"
        case .htmlPreview: return "HTML Preview"
        case .htmlInput: return "HTML Input"
        case .preview: return "Preview"
        case .cronExpressionParser: return "Cron Expression Parser"
        case .cronExpression: return "Cron Expression"
        case .nextRuns: return "Next 10 Runs"
        case .minute: return "Minute"
        case .hour: return "Hour"
        case .day: return "Day"
        case .month: return "Month"
        case .weekday: return "Weekday"
        case .loadExample: return "Load Example"
        case .unixTimestampConverter: return "Unix Timestamp Converter"
        case .currentTime: return "Current Time"
        case .timestampToDate: return "Timestamp → Date"
        case .dateToTimestamp: return "Date → Timestamp"
        case .enterTimestamp: return "Enter timestamp (e.g. 1700000000)"
        case .enterDate: return "Enter date (e.g. 2024-01-01 12:00:00)"
        case .seconds: return "Seconds (s)"
        case .milliseconds: return "Milliseconds (ms)"
        case .invalidDateFormat: return "Invalid date format. Use: yyyy-MM-dd HH:mm:ss"
        case .appearance: return "Appearance"
        case .language: return "Language"
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        // Sidebar sections
        case .sectionEncoding: return "Encoding"
        case .sectionText: return "Text"
        case .sectionJsonYaml: return "JSON / YAML"
        case .sectionWebDev: return "Web / Dev"
        // Sidebar tool names
        case .toolBase64: return "Base64"
        case .toolBase64Image: return "Base64 Image"
        case .toolHash: return "Hash"
        case .toolUrlEncode: return "URL Encode"
        case .toolSqlFormatter: return "SQL Formatter"
        case .toolTextDiff: return "Text Diff"
        case .toolBatchText: return "Batch Text"
        case .toolTokenCounter: return "Token Counter"
        case .toolRegex: return "Regex"
        case .toolJsonEditor: return "JSON Editor"
        case .toolJsonPath: return "JSONPath"
        case .toolYamlJson: return "YAML ↔ JSON"
        case .toolJwtDebugger: return "JWT Debugger"
        case .toolHtmlPreview: return "HTML Preview"
        case .toolMarkdownPreview: return "Markdown Preview"
        case .toolQrCode: return "QR Code"
        case .toolCurlConverter: return "cURL Converter"
        case .toolCronParser: return "Cron Parser"
        case .toolTimestamp: return "Timestamp"
        // JWT
        case .jwtHeader: return "Header"
        case .jwtPayload: return "Payload"
        // Cron descriptions
        case .cronFiveFieldsRequired: return "Cron expression must have 5 fields"
        case .cronEveryMinute: return "Every minute"
        case .cronEveryHour: return "Every hour"
        case .cronEveryDay: return "Every day"
        case .cronEveryMonth: return "Every month"
        case .cronEveryWeekday: return "Every weekday"
        case .cronEveryMinutes: return "Every %d minutes"
        case .cronEveryHours: return "Every %d hours"
        case .cronEveryDays: return "Every %d days"
        case .cronEveryMonths: return "Every %d months"
        case .cronEveryWeekdays: return "Every %d weekdays"
        case .cronFromTo: return "From %@ to %@"
        case .cronAt: return "At %@"
        case .cronRuns: return "Runs %@"
        case .jsonTooLarge: return "JSON too large (%dMB), max %dMB"
        }
    }
    
    private var zh: String {
        switch self {
        case .appTitle: return "OpenDevUtils"
        case .selectTool: return "选择工具"
        case .input: return "输入"
        case .output: return "输出"
        case .paste: return "粘贴"
        case .copy: return "复制"
        case .copyAll: return "全部复制"
        case .clear: return "清空"
        case .execute: return "执行"
        case .convert: return "转换"
        case .test: return "测试"
        case .refresh: return "刷新"
        case .results: return "结果"
        case .noResults: return "无结果"
        case .description: return "描述"
        case .options: return "选项"
        case .base64Title: return "Base64 编码/解码"
        case .encode: return "编码"
        case .decode: return "解码"
        case .hashGenerator: return "哈希生成器"
        case .uppercase: return "大写"
        case .urlEncodeDecode: return "URL 编码/解码"
        case .mode: return "模式"
        case .type: return "类型"
        case .urlComponent: return "URL编码组件"
        case .fullUrl: return "完整URL"
        case .textDiff: return "文本对比"
        case .original: return "原始文本"
        case .modified: return "修改文本"
        case .compare: return "对比"
        case .diffResult: return "对比结果"
        case .ignoreCase: return "忽略大小写"
        case .ignoreWhitespace: return "忽略空白"
        case .clickCompareToSeeDifferences: return "点击对比查看差异"
        case .regularExpression: return "正则表达式"
        case .pattern: return "表达式"
        case .testString: return "测试字符串"
        case .matches: return "匹配结果"
        case .match: return "个匹配"
        case .noMatchesFound: return "未找到匹配"
        case .enterRegexPattern: return "输入正则表达式"
        case .invalidRegexPattern: return "无效的正则表达式"
        case .batchText: return "批量文本处理"
        case .removeDuplicates: return "去重"
        case .sortLines: return "排序"
        case .removeEmptyLines: return "删除空行"
        case .trimWhitespace: return "去除空白"
        case .prefixSuffix: return "前缀 / 后缀"
        case .prefixPlaceholder: return "前缀 (如 http://)"
        case .suffixPlaceholder: return "后缀 (如 .html)"
        case .batchReplace: return "批量替换"
        case .findPlaceholder: return "查找"
        case .replacePlaceholder: return "替换为"
        case .tokenCounter: return "Token 估算"
        case .model: return "模型"
        case .tokenCount: return "Token数"
        case .charCount: return "字符数"
        case .wordCount: return "词数"
        case .lineCount: return "行数"
        case .byteCount: return "字节数"
        case .chineseChars: return "中文字符"
        case .englishWords: return "英文单词"
        case .punctuation: return "标点符号"
        case .tokens: return "tokens"
        case .base64Image: return "Base64 图片"
        case .base64Input: return "Base64 输入"
        case .base64ImageHint: return "粘贴 Base64 编码的图片数据以预览"
        case .saveImage: return "保存图片"
        case .invalidBase64: return "无效的 Base64 数据"
        case .invalidImage: return "无效的图片数据"
        case .jwtDebugger: return "JWT 调试器"
        case .jwtTokenInput: return "JWT Token"
        case .signature: return "签名"
        case .invalidJWT: return "无效的 JWT Token"
        case .markdownPreview: return "Markdown 预览"
        case .markdownInput: return "Markdown 输入"
        case .qrCode: return "二维码"
        case .generate: return "生成"
        case .scanQR: return "识别"
        case .qrCodeInput: return "二维码内容"
        case .sqlFormatter: return "SQL 格式化"
        case .keywordCase: return "关键字大小写"
        case .curlConverter: return "cURL 转换器"
        case .curlInput: return "cURL 命令"
        case .jsonEditor: return "JSON 编辑器"
        case .prettyPrint: return "美化"
        case .minify: return "压缩"
        case .invalidJSON: return "无效的 JSON"
        case .jsonpathQuery: return "JSONPath 查询"
        case .jsonInput: return "JSON 输入"
        case .jsonpathExpression: return "JSONPath 表达式"
        case .loadSample: return "加载示例"
        case .examples: return "示例"
        case .resultsCount: return "个结果"
        case .yamlJsonConverter: return "YAML ↔ JSON 转换器"
        case .yamlToJson: return "YAML → JSON"
        case .jsonToYaml: return "JSON → YAML"
        case .yamlInput: return "YAML 输入"
        case .jsonOutput: return "JSON 输出"
        case .yamlOutput: return "YAML 输出"
        case .htmlPreview: return "HTML 预览"
        case .htmlInput: return "HTML 输入"
        case .preview: return "预览"
        case .cronExpressionParser: return "Cron 表达式解析器"
        case .cronExpression: return "Cron 表达式"
        case .nextRuns: return "下次运行时间"
        case .minute: return "分钟"
        case .hour: return "小时"
        case .day: return "日"
        case .month: return "月"
        case .weekday: return "星期"
        case .loadExample: return "加载示例"
        case .unixTimestampConverter: return "Unix 时间戳转换器"
        case .currentTime: return "当前时间"
        case .timestampToDate: return "时间戳 → 日期"
        case .dateToTimestamp: return "日期 → 时间戳"
        case .enterTimestamp: return "输入时间戳 (如 1700000000)"
        case .enterDate: return "输入日期 (如 2024-01-01 12:00:00)"
        case .seconds: return "秒 (s)"
        case .milliseconds: return "毫秒 (ms)"
        case .invalidDateFormat: return "日期格式无效，请使用: yyyy-MM-dd HH:mm:ss"
        case .appearance: return "外观"
        case .language: return "语言"
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        // Sidebar sections
        case .sectionEncoding: return "编码"
        case .sectionText: return "文本"
        case .sectionJsonYaml: return "JSON / YAML"
        case .sectionWebDev: return "Web / 开发"
        // Sidebar tool names
        case .toolBase64: return "Base64"
        case .toolBase64Image: return "Base64 图片"
        case .toolHash: return "哈希"
        case .toolUrlEncode: return "URL 编码"
        case .toolSqlFormatter: return "SQL 格式化"
        case .toolTextDiff: return "文本对比"
        case .toolBatchText: return "批量文本"
        case .toolTokenCounter: return "Token 估算"
        case .toolRegex: return "正则表达式"
        case .toolJsonEditor: return "JSON 编辑器"
        case .toolJsonPath: return "JSONPath"
        case .toolYamlJson: return "YAML ↔ JSON"
        case .toolJwtDebugger: return "JWT 调试器"
        case .toolHtmlPreview: return "HTML 预览"
        case .toolMarkdownPreview: return "Markdown 预览"
        case .toolQrCode: return "二维码"
        case .toolCurlConverter: return "cURL 转换器"
        case .toolCronParser: return "Cron 解析器"
        case .toolTimestamp: return "时间戳"
        // JWT
        case .jwtHeader: return "头部"
        case .jwtPayload: return "载荷"
        // Cron descriptions
        case .cronFiveFieldsRequired: return "Cron 表达式必须包含 5 个字段"
        case .cronEveryMinute: return "每分钟"
        case .cronEveryHour: return "每小时"
        case .cronEveryDay: return "每天"
        case .cronEveryMonth: return "每月"
        case .cronEveryWeekday: return "每个工作日"
        case .cronEveryMinutes: return "每 %d 分钟"
        case .cronEveryHours: return "每 %d 小时"
        case .cronEveryDays: return "每 %d 天"
        case .cronEveryMonths: return "每 %d 月"
        case .cronEveryWeekdays: return "每 %d 个工作日"
        case .cronFromTo: return "从 %@ 到 %@"
        case .cronAt: return "在 %@"
        case .cronRuns: return "执行 %@"
        case .jsonTooLarge: return "JSON 过大（%dMB），上限 %dMB"
        }
    }
    
    private var ja: String {
        switch self {
        case .appTitle: return "OpenDevUtils"
        case .selectTool: return "ツールを選択"
        case .input: return "入力"
        case .output: return "出力"
        case .paste: return "貼り付け"
        case .copy: return "コピー"
        case .copyAll: return "すべてコピー"
        case .clear: return "クリア"
        case .execute: return "実行"
        case .convert: return "変換"
        case .test: return "テスト"
        case .refresh: return "更新"
        case .results: return "結果"
        case .noResults: return "結果なし"
        case .description: return "説明"
        case .options: return "オプション"
        case .base64Title: return "Base64 エンコード/デコード"
        case .encode: return "エンコード"
        case .decode: return "デコード"
        case .hashGenerator: return "ハッシュ生成器"
        case .uppercase: return "大文字"
        case .urlEncodeDecode: return "URL エンコード/デコード"
        case .mode: return "モード"
        case .type: return "タイプ"
        case .urlComponent: return "URLコンポーネント"
        case .fullUrl: return "完全なURL"
        case .textDiff: return "テキスト差分"
        case .original: return "元のテキスト"
        case .modified: return "変更テキスト"
        case .compare: return "比較"
        case .diffResult: return "差分結果"
        case .ignoreCase: return "大文字小文字を無視"
        case .ignoreWhitespace: return "空白を無視"
        case .clickCompareToSeeDifferences: return "比較をクリックして差分を表示"
        case .regularExpression: return "正規表現"
        case .pattern: return "パターン"
        case .testString: return "テスト文字列"
        case .matches: return "一致"
        case .match: return "件一致"
        case .noMatchesFound: return "一致なし"
        case .enterRegexPattern: return "正規表現パターンを入力"
        case .invalidRegexPattern: return "無効な正規表現パターン"
        case .batchText: return "バッチテキスト処理"
        case .removeDuplicates: return "重複除去"
        case .sortLines: return "並べ替え"
        case .removeEmptyLines: return "空行除去"
        case .trimWhitespace: return "空白除去"
        case .prefixSuffix: return "プレフィックス / サフィックス"
        case .prefixPlaceholder: return "プレフィックス (例: http://)"
        case .suffixPlaceholder: return "サフィックス (例: .html)"
        case .batchReplace: return "一括置換"
        case .findPlaceholder: return "検索"
        case .replacePlaceholder: return "置換"
        case .tokenCounter: return "トークンカウンター"
        case .model: return "モデル"
        case .tokenCount: return "トークン数"
        case .charCount: return "文字数"
        case .wordCount: return "単語数"
        case .lineCount: return "行数"
        case .byteCount: return "バイト数"
        case .chineseChars: return "中国語"
        case .englishWords: return "英語"
        case .punctuation: return "句読点"
        case .tokens: return "トークン"
        case .base64Image: return "Base64 画像"
        case .base64Input: return "Base64 入力"
        case .base64ImageHint: return "Base64 エンコード画像データを貼り付けてプレビュー"
        case .saveImage: return "画像を保存"
        case .invalidBase64: return "無効な Base64 データ"
        case .invalidImage: return "無効な画像データ"
        case .jwtDebugger: return "JWT デバッガー"
        case .jwtTokenInput: return "JWT Token"
        case .signature: return "署名"
        case .invalidJWT: return "無効な JWT Token"
        case .markdownPreview: return "Markdown プレビュー"
        case .markdownInput: return "Markdown 入力"
        case .qrCode: return "QRコード"
        case .generate: return "生成"
        case .scanQR: return "読み取り"
        case .qrCodeInput: return "QRコード内容"
        case .sqlFormatter: return "SQL フォーマッター"
        case .keywordCase: return "キーワード大文字小文字"
        case .curlConverter: return "cURL 変換器"
        case .curlInput: return "cURL コマンド"
        case .jsonEditor: return "JSON エディタ"
        case .prettyPrint: return "整形"
        case .minify: return "圧縮"
        case .invalidJSON: return "無効な JSON"
        case .jsonpathQuery: return "JSONPath クエリ"
        case .jsonInput: return "JSON 入力"
        case .jsonpathExpression: return "JSONPath 式"
        case .loadSample: return "サンプル読み込み"
        case .examples: return "例"
        case .resultsCount: return "件の結果"
        case .yamlJsonConverter: return "YAML ↔ JSON 変換器"
        case .yamlToJson: return "YAML → JSON"
        case .jsonToYaml: return "JSON → YAML"
        case .yamlInput: return "YAML 入力"
        case .jsonOutput: return "JSON 出力"
        case .yamlOutput: return "YAML 出力"
        case .htmlPreview: return "HTML プレビュー"
        case .htmlInput: return "HTML 入力"
        case .preview: return "プレビュー"
        case .cronExpressionParser: return "Cron式パーサー"
        case .cronExpression: return "Cron式"
        case .nextRuns: return "次回の実行"
        case .minute: return "分"
        case .hour: return "時"
        case .day: return "日"
        case .month: return "月"
        case .weekday: return "曜日"
        case .loadExample: return "サンプル読み込み"
        case .unixTimestampConverter: return "Unix タイムスタンプ変換器"
        case .currentTime: return "現在時刻"
        case .timestampToDate: return "タイムスタンプ → 日付"
        case .dateToTimestamp: return "日付 → タイムスタンプ"
        case .enterTimestamp: return "タイムスタンプを入力 (例: 1700000000)"
        case .enterDate: return "日付を入力 (例: 2024-01-01 12:00:00)"
        case .seconds: return "秒 (s)"
        case .milliseconds: return "ミリ秒 (ms)"
        case .invalidDateFormat: return "日付形式が無効です。使用: yyyy-MM-dd HH:mm:ss"
        case .appearance: return "外観"
        case .language: return "言語"
        case .system: return "システム"
        case .light: return "ライト"
        case .dark: return "ダーク"
        // Sidebar sections
        case .sectionEncoding: return "エンコーディング"
        case .sectionText: return "テキスト"
        case .sectionJsonYaml: return "JSON / YAML"
        case .sectionWebDev: return "Web / 開発"
        // Sidebar tool names
        case .toolBase64: return "Base64"
        case .toolBase64Image: return "Base64 画像"
        case .toolHash: return "ハッシュ"
        case .toolUrlEncode: return "URL エンコード"
        case .toolSqlFormatter: return "SQL フォーマッター"
        case .toolTextDiff: return "テキスト差分"
        case .toolBatchText: return "バッチテキスト"
        case .toolTokenCounter: return "トークンカウンター"
        case .toolRegex: return "正規表現"
        case .toolJsonEditor: return "JSON エディタ"
        case .toolJsonPath: return "JSONPath"
        case .toolYamlJson: return "YAML ↔ JSON"
        case .toolJwtDebugger: return "JWT デバッガー"
        case .toolHtmlPreview: return "HTML プレビュー"
        case .toolMarkdownPreview: return "Markdown プレビュー"
        case .toolQrCode: return "QRコード"
        case .toolCurlConverter: return "cURL 変換器"
        case .toolCronParser: return "Cron パーサー"
        case .toolTimestamp: return "タイムスタンプ"
        // JWT
        case .jwtHeader: return "ヘッダー"
        case .jwtPayload: return "ペイロード"
        // Cron descriptions
        case .cronFiveFieldsRequired: return "Cron式には5つのフィールドが必要です"
        case .cronEveryMinute: return "毎分"
        case .cronEveryHour: return "毎時"
        case .cronEveryDay: return "毎日"
        case .cronEveryMonth: return "毎月"
        case .cronEveryWeekday: return "毎平日"
        case .cronEveryMinutes: return "%d 分ごと"
        case .cronEveryHours: return "%d 時間ごと"
        case .cronEveryDays: return "%d 日ごと"
        case .cronEveryMonths: return "%d ヶ月ごと"
        case .cronEveryWeekdays: return "%d 平日ごと"
        case .cronFromTo: return "%@ から %@ まで"
        case .cronAt: return "%@ で"
        case .cronRuns: return "%@ に実行"
        case .jsonTooLarge: return "JSONが大きすぎます（%dMB）、上限 %dMB"
        }
    }
    
    private var ko: String {
        switch self {
        case .appTitle: return "OpenDevUtils"
        case .selectTool: return "도구 선택"
        case .input: return "입력"
        case .output: return "출력"
        case .paste: return "붙여넣기"
        case .copy: return "복사"
        case .copyAll: return "모두 복사"
        case .clear: return "지우기"
        case .execute: return "실행"
        case .convert: return "변환"
        case .test: return "테스트"
        case .refresh: return "새로고침"
        case .results: return "결과"
        case .noResults: return "결과 없음"
        case .description: return "설명"
        case .options: return "옵션"
        case .base64Title: return "Base64 인코딩/디코딩"
        case .encode: return "인코딩"
        case .decode: return "디코딩"
        case .hashGenerator: return "해시 생성기"
        case .uppercase: return "대문자"
        case .urlEncodeDecode: return "URL 인코딩/디코딩"
        case .mode: return "모드"
        case .type: return "유형"
        case .urlComponent: return "URL 컴포넌트"
        case .fullUrl: return "전체 URL"
        case .textDiff: return "텍스트 차이점"
        case .original: return "원본"
        case .modified: return "수정본"
        case .compare: return "비교"
        case .diffResult: return "차이점 결과"
        case .ignoreCase: return "대소문자 무시"
        case .ignoreWhitespace: return "공백 무시"
        case .clickCompareToSeeDifferences: return "비교를 클릭하여 차이점 보기"
        case .regularExpression: return "정규 표현식"
        case .pattern: return "패턴"
        case .testString: return "테스트 문자열"
        case .matches: return "일치"
        case .match: return "건 일치"
        case .noMatchesFound: return "일치 없음"
        case .enterRegexPattern: return "정규 표현식 패턴 입력"
        case .invalidRegexPattern: return "잘못된 정규 표현식"
        case .batchText: return "배치 텍스트 처리"
        case .removeDuplicates: return "중복 제거"
        case .sortLines: return "정렬"
        case .removeEmptyLines: return "빈 줄 제거"
        case .trimWhitespace: return "공백 제거"
        case .prefixSuffix: return "접두사 / 접미사"
        case .prefixPlaceholder: return "접두사 (예: http://)"
        case .suffixPlaceholder: return "접미사 (예: .html)"
        case .batchReplace: return "일괄 바꾸기"
        case .findPlaceholder: return "찾기"
        case .replacePlaceholder: return "바꾸기"
        case .tokenCounter: return "토큰 카운터"
        case .model: return "모델"
        case .tokenCount: return "토큰 수"
        case .charCount: return "문자 수"
        case .wordCount: return "단어 수"
        case .lineCount: return "줄 수"
        case .byteCount: return "바이트 수"
        case .chineseChars: return "중국어"
        case .englishWords: return "영어"
        case .punctuation: return "구두점"
        case .tokens: return "토큰"
        case .base64Image: return "Base64 이미지"
        case .base64Input: return "Base64 입력"
        case .base64ImageHint: return "Base64 인코딩 이미지 데이터를 붙여넣어 미리보기"
        case .saveImage: return "이미지 저장"
        case .invalidBase64: return "잘못된 Base64 데이터"
        case .invalidImage: return "잘못된 이미지 데이터"
        case .jwtDebugger: return "JWT 디버거"
        case .jwtTokenInput: return "JWT Token"
        case .signature: return "서명"
        case .invalidJWT: return "잘못된 JWT Token"
        case .markdownPreview: return "Markdown 미리보기"
        case .markdownInput: return "Markdown 입력"
        case .qrCode: return "QR코드"
        case .generate: return "생성"
        case .scanQR: return "읽기"
        case .qrCodeInput: return "QR코드 내용"
        case .sqlFormatter: return "SQL 포맷터"
        case .keywordCase: return "키워드 대소문자"
        case .curlConverter: return "cURL 변환기"
        case .curlInput: return "cURL 명령어"
        case .jsonEditor: return "JSON 편집기"
        case .prettyPrint: return "예쁘게 출력"
        case .minify: return "압축"
        case .invalidJSON: return "잘못된 JSON"
        case .jsonpathQuery: return "JSONPath 쿼리"
        case .jsonInput: return "JSON 입력"
        case .jsonpathExpression: return "JSONPath 표현식"
        case .loadSample: return "샘플 로드"
        case .examples: return "예시"
        case .resultsCount: return "건의 결과"
        case .yamlJsonConverter: return "YAML ↔ JSON 변환기"
        case .yamlToJson: return "YAML → JSON"
        case .jsonToYaml: return "JSON → YAML"
        case .yamlInput: return "YAML 입력"
        case .jsonOutput: return "JSON 출력"
        case .yamlOutput: return "YAML 출력"
        case .htmlPreview: return "HTML 미리보기"
        case .htmlInput: return "HTML 입력"
        case .preview: return "미리보기"
        case .cronExpressionParser: return "Cron 표현식 파서"
        case .cronExpression: return "Cron 표현식"
        case .nextRuns: return "다음 10회 실행"
        case .minute: return "분"
        case .hour: return "시"
        case .day: return "일"
        case .month: return "월"
        case .weekday: return "요일"
        case .loadExample: return "예시 로드"
        case .unixTimestampConverter: return "Unix 타임스탬프 변환기"
        case .currentTime: return "현재 시간"
        case .timestampToDate: return "타임스탬프 → 날짜"
        case .dateToTimestamp: return "날짜 → 타임스탬프"
        case .enterTimestamp: return "타임스탬프 입력 (예: 1700000000)"
        case .enterDate: return "날짜 입력 (예: 2024-01-01 12:00:00)"
        case .seconds: return "초 (s)"
        case .milliseconds: return "밀리초 (ms)"
        case .invalidDateFormat: return "날짜 형식이 잘못됨. 사용: yyyy-MM-dd HH:mm:ss"
        case .appearance: return "외관"
        case .language: return "언어"
        case .system: return "시스템"
        case .light: return "라이트"
        case .dark: return "다크"
        // Sidebar sections
        case .sectionEncoding: return "인코딩"
        case .sectionText: return "텍스트"
        case .sectionJsonYaml: return "JSON / YAML"
        case .sectionWebDev: return "Web / 개발"
        // Sidebar tool names
        case .toolBase64: return "Base64"
        case .toolBase64Image: return "Base64 이미지"
        case .toolHash: return "해시"
        case .toolUrlEncode: return "URL 인코딩"
        case .toolSqlFormatter: return "SQL 포맷터"
        case .toolTextDiff: return "텍스트 차이점"
        case .toolBatchText: return "배치 텍스트"
        case .toolTokenCounter: return "토큰 카운터"
        case .toolRegex: return "정규 표현식"
        case .toolJsonEditor: return "JSON 편집기"
        case .toolJsonPath: return "JSONPath"
        case .toolYamlJson: return "YAML ↔ JSON"
        case .toolJwtDebugger: return "JWT 디버거"
        case .toolHtmlPreview: return "HTML 미리보기"
        case .toolMarkdownPreview: return "Markdown 미리보기"
        case .toolQrCode: return "QR코드"
        case .toolCurlConverter: return "cURL 변환기"
        case .toolCronParser: return "Cron 파서"
        case .toolTimestamp: return "타임스탬프"
        // JWT
        case .jwtHeader: return "헤더"
        case .jwtPayload: return "페이로드"
        // Cron descriptions
        case .cronFiveFieldsRequired: return "Cron 표현식은 5개 필드가 필요합니다"
        case .cronEveryMinute: return "매 분"
        case .cronEveryHour: return "매 시"
        case .cronEveryDay: return "매일"
        case .cronEveryMonth: return "매월"
        case .cronEveryWeekday: return "매 평일"
        case .cronEveryMinutes: return "%d분마다"
        case .cronEveryHours: return "%d시간마다"
        case .cronEveryDays: return "%d일마다"
        case .cronEveryMonths: return "%d개월마다"
        case .cronEveryWeekdays: return "%d 평일마다"
        case .cronFromTo: return "%@부터 %@까지"
        case .cronAt: return "%@에"
        case .cronRuns: return "%@에 실행"
        case .jsonTooLarge: return "JSON이 너무 큽니다（%dMB）, 최대 %dMB"
        }
    }
}
