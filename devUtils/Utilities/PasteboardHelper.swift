import AppKit

/// Centralized pasteboard operations to eliminate duplication across tools.
enum PasteboardHelper {
    /// Read a string from the general pasteboard.
    static func readString() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }
    
    /// Write a string to the general pasteboard.
    static func writeString(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
