import SwiftUI

enum ToolCategory: String, CaseIterable, Identifiable {
    case encoding = "Encoding"
    case text = "Text"
    case json = "JSON"
    case webDev = "Web / Dev"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .encoding: return "lock.fill"
        case .text: return "doc.text"
        case .json: return "doc.text.fill"
        case .webDev: return "globe"
        }
    }
}

protocol Tool: Identifiable, View {
    var id: String { get }
    var name: String { get }
    var icon: String { get }
    var category: ToolCategory { get }
}
