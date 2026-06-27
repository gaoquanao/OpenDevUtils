import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case en = "English"
    case zh = "中文"
    case ja = "日本語"
    case ko = "한국어"
    
    var id: String { rawValue }
    
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en")
        case .zh: return Locale(identifier: "zh-Hans")
        case .ja: return Locale(identifier: "ja")
        case .ko: return Locale(identifier: "ko")
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "English"
        self.language = AppLanguage(rawValue: saved) ?? .en
    }
    
    func t(_ key: LocalizedString) -> String {
        key.text(for: language)
    }
}

func L(_ key: LocalizedString) -> String {
    LanguageManager.shared.t(key)
}
