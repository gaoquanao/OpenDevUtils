import SwiftUI

// Simulated Liquid Glass style using available SwiftUI materials
// Creates a frosted glass effect similar to Apple's Liquid Glass design

struct GlassActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}

struct GlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .foregroundStyle(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
    }
}

struct GlassToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
    }
}

struct GlassSectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

extension View {
    func glassActionButton() -> some View {
        buttonStyle(GlassActionButtonStyle())
    }
    
    func glassProminentButton() -> some View {
        buttonStyle(GlassProminentButtonStyle())
    }
    
    func glassToolbarButton() -> some View {
        buttonStyle(GlassToolbarButtonStyle())
    }
    
    func glassSectionHeader() -> some View {
        modifier(GlassSectionHeaderStyle())
    }
    
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
}
