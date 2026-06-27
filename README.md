# OpenDevUtils

> macOS developer toolkit — a collection of 19 essential utilities for everyday development tasks.

> macOS 开发者工具箱 — 19 个常用开发工具合集，覆盖编码转换、文本处理、JSON/YAML、Web 开发等场景。

---

## Features / 功能一览

### Encoding / 编码转换

| Tool | Description | 工具 | 说明 |
|------|-------------|------|------|
| Base64 | Encode and decode Base64 strings | Base64 | Base64 编码与解码 |
| Base64 Image | Preview Base64-encoded images, save as PNG/JPEG | Base64 图片 | 预览 Base64 图片，支持保存 |
| Hash | Generate MD5, SHA1, SHA256, SHA512 hashes | 哈希 | 生成 MD5、SHA1、SHA256、SHA512 |
| URL Encode | URL component and full URL encoding/decoding | URL 编码 | URL 组件/完整 URL 编解码 |
| SQL Formatter | Format and beautify SQL queries | SQL 格式化 | SQL 语句格式化美化 |

### Text / 文本处理

| Tool | Description | 工具 | 说明 |
|------|-------------|------|------|
| Text Diff | Compare two texts side by side | 文本对比 | 左右对比两段文本 |
| Batch Text | Deduplicate, sort, add prefix/suffix, find & replace | 批量处理 | 去重、排序、前后缀、批量替换 |
| Token Counter | Estimate LLM token counts (GPT-4, GPT-3.5, etc.) | Token 估算 | 估算大模型 Token 数量 |
| Regex | Test regular expressions with match highlighting | 正则测试 | 正则表达式测试与高亮 |

### JSON / YAML

| Tool | Description | 工具 | 说明 |
|------|-------------|------|------|
| JSON Editor | Pretty print and minify JSON | JSON 编辑器 | JSON 美化与压缩 |
| JSONPath | Query JSON with JSONPath expressions | JSONPath | JSONPath 表达式查询 |
| YAML ↔ JSON | Convert between YAML and JSON | YAML ↔ JSON | YAML 与 JSON 互转 |
| JWT Debugger | Decode JWT tokens, view header/payload/signature | JWT 调试器 | JWT Token 解码查看 |

### Web / Dev / Web 开发

| Tool | Description | 工具 | 说明 |
|------|-------------|------|------|
| HTML Preview | Live preview HTML with WebKit | HTML 预览 | 实时预览 HTML |
| Markdown Preview | Render Markdown with GitHub-style formatting | Markdown 预览 | Markdown 渲染预览 |
| QR Code | Generate QR codes from text | 二维码 | 文本生成二维码 |
| cURL Converter | Convert cURL to Swift, Python, JS, Go, PHP, Java | cURL 转换 | cURL 转 6 种语言代码 |
| Cron Parser | Parse cron expressions and show next run times | Cron 解析 | Cron 表达式解析 |
| Timestamp | Unix timestamp ↔ date conversion | 时间戳 | Unix 时间戳与日期互转 |

---

## Screenshots / 截图

<p align="center">
  <img src="/pic/Screenshot.png" width="800" alt="OpenDevUtils Screenshot">
</p>

---

## Requirements / 环境要求

- macOS 13.0 or later / macOS 13.0 或更高版本
- Swift 5.9+
- Python 3 (for icon generation / 生成图标)

---

## Installation / 安装

### Build from source / 从源码构建

```bash
# Clone the repository / 克隆仓库
git clone <repository-url>
cd devUtils

# Build release binary / 构建 Release 版本
./build.sh

# The .app bundle will be at .build/OpenDevUtils.app
# 应用将生成在 .build/OpenDevUtils.app
```

### Create DMG installer / 创建 DMG 安装包

```bash
./package.sh
# DMG will be at .build/OpenDevUtils.dmg
# DMG 将生成在 .build/OpenDevUtils.dmg
```

### Run tests / 运行测试

```bash
swift test
```

---

## Architecture / 项目架构

```
devUtils/
├── devUtilsApp.swift              # App entry point / 应用入口
├── ContentView.swift              # NavigationSplitView / 侧边栏导航
├── Models/
│   └── Tool.swift                 # Tool protocol & categories / 工具协议
├── Tools/                         # 19 tool views / 19 个工具视图
├── Utilities/
│   ├── LocalizedString.swift      # 4-language i18n (en/zh/ja/ko)
│   ├── LanguageManager.swift      # Language switching / 语言切换
│   ├── AppearanceManager.swift    # Theme switching / 主题切换
│   ├── DisableSmartQuotes.swift   # Disables text auto-correction
│   ├── JSONPathEngine.swift       # JSONPath query engine
│   ├── LiquidGlassStyle.swift     # Glass effect styles
│   └── SyntaxHighlighter.swift    # Code syntax highlighting
└── Tests/                         # Unit tests / 单元测试
```

---

## Tech Stack / 技术栈

| Component | Technology | 组件 | 技术 |
|-----------|-----------|------|------|
| UI | SwiftUI | 界面 | SwiftUI |
| Build | Swift Package Manager | 构建 | Swift Package Manager |
| Icons | Python + Pillow | 图标 | Python + Pillow |
| Packaging | hdiutil + AppleScript | 打包 | hdiutil + AppleScript |
| i18n | Custom enum-based localization | 国际化 | 自定义枚举本地化 |

---

## Supported Languages / 支持语言

- 🇺🇸 English
- 🇨🇳 中文
- 🇯🇵 日本語
- 🇰🇷 한국어

---

## License / 许可

 Apache-2.0 license / Apache 许可证
