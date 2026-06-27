# OpenDevUtils

macOS developer utility app built with SwiftUI + SPM (no Xcode project).

## Build & Run

```bash
# Development build
swift build

# Release build + .app bundle
./build.sh

# Package as DMG
./package.sh

# Run tests
swift test
```

## Project Structure

```
devUtils/
├── devUtilsApp.swift          # App entry, disables smart quotes globally
├── ContentView.swift          # NavigationSplitView sidebar + detail routing
├── Models/Tool.swift          # ToolCategory enum + Tool protocol
├── Tools/                     # 19 tool views, one per file
│   ├── Base64Tool.swift       └── TimestampTool.swift
├── Utilities/
│   ├── LocalizedString.swift  # 4-language strings (en/zh/ja/ko)
│   ├── LanguageManager.swift  # Language singleton
│   ├── AppearanceManager.swift# Theme singleton
│   ├── DisableSmartQuotes.swift # Disables all NSTextView autonomous behaviors
│   ├── JSONPathEngine.swift   # Custom JSONPath parser
│   ├── LiquidGlassStyle.swift # Simulated glass styles (.ultraThinMaterial)
│   └── SyntaxHighlighter.swift# Code highlighting via tokenizer
Tests/                         # 5 test files (JSONPath, JWT, TextDiff, Token, YAML)
```

## Key Conventions

- **Tool pattern**: Each tool conforms to `Tool` protocol (`id`, `name`, `icon`, `category`). Add to `ToolID` enum in ContentView.swift and `detail` switch.
- **Output TextEditors**: Use `.textSelection(.enabled)` not `.disabled(true)` — users must be able to copy.
- **TextEditor autonomous behaviors**: All disabled globally in `devUtilsApp.init()` via UserDefaults + `DisableSmartQuotes`. Do not re-enable.
- **Localization**: Use `L(.key)` function. Add new keys to all 4 language sections in `LocalizedString.swift`.
- **Glass styles**: Use `.glassActionButton()` / `.glassProminentButton()` from LiquidGlassStyle.swift. These simulate Liquid Glass with `.ultraThinMaterial` (native API requires macOS 26+/Xcode 26).
- **Icon pipeline**: `generate_icon.py` → `icon.iconset/` → `icon_full.icns` → `build.sh` copies to `.app/Resources/AppIcon.icns`. Never generate `.icns` via `iconutil` in build — use the pre-built file.
- **Package.swift target**: `.macOS(.v13)`. Do not change to `.v26` — SPM toolchain doesn't support it.

## Gotchas

- `icon.iconset` directory must NOT be in the `.app` bundle — only `AppIcon.icns` goes there.
- `CFBundleIconFile` in Info.plist must point to `AppIcon.icns`, not `icon`.
- Liquid Glass APIs (`GlassEffectContainer`, `.glassEffect`) don't compile with current Xcode — use simulated styles only.
- YAML parser is minimal (flat dicts, arrays, comments). Don't add complex YAML features without tests.
- `JSONPathEngine.evaluate()` throws on missing keys — callers must catch.
