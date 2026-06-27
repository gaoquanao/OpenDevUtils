import SwiftUI

extension View {
    func localized(_ key: LocalizedString) -> some View {
        modifier(LocalizedTextModifier(key: key))
    }
}

struct LocalizedTextModifier: ViewModifier {
    let key: LocalizedString
    @ObservedObject private var lang = LanguageManager.shared
    
    func body(content: Content) -> some View {
        content
    }
}

extension Text {
    init(_ key: LocalizedString) {
        self.init(key.text(for: LanguageManager.shared.language))
    }
}
