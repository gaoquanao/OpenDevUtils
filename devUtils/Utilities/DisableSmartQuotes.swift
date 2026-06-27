import SwiftUI
import AppKit

// Disable ALL autonomous TextEditor behaviors for developer tools
func disableSmartQuotesSystemWide() {
    let defaults = UserDefaults.standard
    defaults.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
    defaults.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
    defaults.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
    defaults.set(false, forKey: "NSAutomaticTextReplacementEnabled")
    defaults.set(false, forKey: "NSAutomaticCapitalizationEnabled")
    defaults.set(false, forKey: "NSAutomaticLinkDetectionEnabled")
    defaults.set(false, forKey: "NSAutomaticDataDetectionEnabled")
    defaults.set(false, forKey: "NSAutomaticTextCompletionEnabled")
}

struct DisableSmartQuotes: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                if let window = NSApp.keyWindow {
                    configureWindow(window)
                }
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let window = notification.object as? NSWindow {
                        configureWindow(window)
                    }
                }
            }
    }
    
    private func configureWindow(_ window: NSWindow) {
        for textView in window.contentView?.findAllTextViews() ?? [] {
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.isAutomaticDataDetectionEnabled = false
            textView.isAutomaticTextCompletionEnabled = false
            textView.isRichText = false
            textView.textStorage?.setAttributes([:], range: NSRange(location: 0, length: textView.textStorage?.length ?? 0))
        }
    }
}

extension NSView {
    func findTextView() -> NSTextView? {
        if let tv = self as? NSTextView { return tv }
        for subview in subviews {
            if let found = subview.findTextView() { return found }
        }
        return nil
    }
    
    func findAllTextViews() -> [NSTextView] {
        var result: [NSTextView] = []
        if let tv = self as? NSTextView { result.append(tv) }
        for subview in subviews {
            result.append(contentsOf: subview.findAllTextViews())
        }
        return result
    }
}

extension View {
    func disableSmartQuotes() -> some View {
        modifier(DisableSmartQuotes())
    }
}
