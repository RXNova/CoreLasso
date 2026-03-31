import SwiftUI
import LassoCore

/// Button variant following Material Design contained / outlined semantics.
public enum GlassButtonVariant: Sendable {
    /// Filled / Contained — solid primary color, white text, elevation shadow.
    case primary
    /// Outlined — transparent background, primary-colored border and text.
    case secondary
}

/// A Material-style `ButtonStyle`.
///
/// ```swift
/// Button("Start") { }
///     .buttonStyle(GlassButtonStyle(.primary))
/// ```
public struct GlassButtonStyle: ButtonStyle {

    private let variant: GlassButtonVariant

    public init(_ variant: GlassButtonVariant = .primary) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, LassoSpacing.md.rawValue)
            .padding(.vertical, 7)
            .background(background(configuration.isPressed))
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
            .overlay(border)
            .shadow(color: elevation(configuration.isPressed), radius: 3, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(Rectangle())
            .pointerStyle(.link)
    }

    // MARK: - Helpers

    private func background(_ pressed: Bool) -> Color {
        switch variant {
        case .primary:
            return pressed
                ? LassoColors.antBlue.opacity(0.88)
                : LassoColors.antBlue
        case .secondary:
            return pressed
                ? LassoColors.antBlue.opacity(0.08)
                : Color.clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:   .white
        case .secondary: LassoColors.antBlue
        }
    }

    @ViewBuilder private var border: some View {
        switch variant {
        case .primary:
            EmptyView()
        case .secondary:
            RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                .stroke(LassoColors.antBlue, lineWidth: 1)
        }
    }

    private func elevation(_ pressed: Bool) -> Color {
        switch variant {
        case .primary:   pressed ? .clear : Color.black.opacity(0.22)
        case .secondary: .clear
        }
    }
}
