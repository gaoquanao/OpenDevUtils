import SwiftUI
import AppKit
import ObjectiveC

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

private var didConfigureKey: UInt8 = 0
private var managedAttributesKey: UInt8 = 0

/// Marks a text view as owning its own attributes (syntax-highlighted
/// editors), so the one-time attribute wipe in `configureWindow` doesn't
/// destroy its colors and font.
func markTextViewAttributesManaged(_ textView: NSTextView) {
    objc_setAssociatedObject(textView, &managedAttributesKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}

struct DisableSmartQuotes: ViewModifier {
    /// Process-wide observer token. The previous implementation registered a
    /// fresh block observer on every `.onAppear` and never removed it, so
    /// switching tools leaked one observer (plus a full window walk on every
    /// focus change) per modifier, forever.
    private static var windowObserver: NSObjectProtocol?

    func body(content: Content) -> some View {
        content
            .onAppear {
                Self.registerObserverIfNeeded()
                if let window = NSApp.keyWindow {
                    Self.configureWindow(window)
                }
            }
    }

    private static func registerObserverIfNeeded() {
        guard windowObserver == nil else { return }
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                configureWindow(window)
            }
        }
    }

    private static func configureWindow(_ window: NSWindow) {
        for textView in window.contentView?.findAllTextViews() ?? [] {
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.isAutomaticDataDetectionEnabled = false
            textView.isAutomaticTextCompletionEnabled = false
            textView.isRichText = false
            // Reset attributes only once per text view: doing it on every
            // window-focus change was O(document length) and destroyed the
            // fonts of large editors.
            if objc_getAssociatedObject(textView, &didConfigureKey) == nil {
                if objc_getAssociatedObject(textView, &managedAttributesKey) == nil {
                    textView.textStorage?.setAttributes([:], range: NSRange(location: 0, length: textView.textStorage?.length ?? 0))
                }
                objc_setAssociatedObject(textView, &didConfigureKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}

extension NSView {
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
