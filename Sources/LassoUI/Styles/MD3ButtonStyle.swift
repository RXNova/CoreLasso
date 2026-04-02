import SwiftUI

// MARK: - Button Variant

/// Material Design 3 button variants.
public enum MD3ButtonVariant: Sendable {
    /// Filled — primary background, onPrimary text, elevation on press.
    case filled
    /// Tonal — secondaryContainer background, onSecondaryContainer text.
    case tonal
    /// Elevated — surfaceContainerLow background, primary text, elevation shadow.
    case elevated
    /// Outlined — transparent background, outline border, primary text.
    case outlined
    /// Text — no background, no border, primary text.
    case text
}

// MARK: - MD3 Button Style

/// A Material Design 3 `ButtonStyle`.
///
/// ```swift
/// Button("Start") { }
///     .buttonStyle(MD3ButtonStyle(.filled))
/// ```
public struct MD3ButtonStyle: ButtonStyle {

    @Environment(\.md3Scheme) private var scheme
    private let variant: MD3ButtonVariant

    public init(_ variant: MD3ButtonVariant = .filled) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MD3Typography.labelLarge)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(background(configuration.isPressed))
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(border)
            .overlay(stateLayer(configuration.isPressed))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .contentShape(Rectangle())
            .pointerStyle(.link)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    // MARK: - Styling

    private var horizontalPadding: CGFloat {
        switch variant {
        case .text: 12
        default:    20
        }
    }

    private func background(_ pressed: Bool) -> Color {
        switch variant {
        case .filled:   scheme.primary
        case .tonal:    scheme.secondaryContainer
        case .elevated: scheme.surfaceContainerLow
        case .outlined: .clear
        case .text:     .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .filled:   scheme.onPrimary
        case .tonal:    scheme.onSecondaryContainer
        case .elevated: scheme.primary
        case .outlined: scheme.primary
        case .text:     scheme.primary
        }
    }

    @ViewBuilder
    private var border: some View {
        switch variant {
        case .outlined:
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(scheme.outline, lineWidth: 1)
        default:
            EmptyView()
        }
    }

    private func stateLayer(_ pressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(stateLayerColor.opacity(pressed ? 0.12 : 0))
            .allowsHitTesting(false)
    }

    private var stateLayerColor: Color {
        switch variant {
        case .filled:   scheme.onPrimary
        case .tonal:    scheme.onSecondaryContainer
        case .elevated: scheme.primary
        case .outlined: scheme.primary
        case .text:     scheme.primary
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .elevated: Color.black.opacity(0.15)
        case .filled:   Color.black.opacity(0.10)
        default:        .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch variant {
        case .elevated: 3
        case .filled:   2
        default:        0
        }
    }

    private var shadowY: CGFloat {
        switch variant {
        case .elevated: 1
        case .filled:   1
        default:        0
        }
    }
}

