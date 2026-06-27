import SwiftUI

enum AppAppearance: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
            apply()
        }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "appAppearance") ?? "System"
        self.appearance = AppAppearance(rawValue: saved) ?? .system
        apply()
    }
    
    func apply() {
        NSApp.appearance = appearance.nsAppearance
    }
}
