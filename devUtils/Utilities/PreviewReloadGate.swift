import Foundation

/// Decides whether a web preview should reload.
///
/// `HTMLWebView.updateNSView` used to call `loadHTMLString` on every SwiftUI
/// update (the `id` was never read), so previews reloaded on every keystroke,
/// losing scroll position and flashing white. This gate reloads only when the
/// id (explicit Refresh) or the content actually changed.
struct ReloadGate {
    private var lastID: UUID?
    private var lastHTML: String?

    init() {}

    mutating func shouldReload(id: UUID, html: String) -> Bool {
        if id == lastID && html == lastHTML {
            return false
        }
        lastID = id
        lastHTML = html
        return true
    }
}
