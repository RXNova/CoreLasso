import SwiftUI

// MARK: - Card Variant

/// Material Design 3 card variants.
public enum MD3CardVariant: Sendable {
    /// Elevated: surface background + tint at elevation 1 + shadow.
    case elevated
    /// Filled: surfaceContainerHighest background, no shadow, no border.
    case filled
    /// Outlined: surface background + subtle border + light shadow.
    case outlined
}

// MARK: - Card View Modifier

/// Applies MD3 card styling to any view.
public struct MD3CardModifier: ViewModifier {

    @Environment(\.md3Scheme) private var scheme
    private let variant: MD3CardVariant
    private let cornerRadius: CGFloat

    public init(_ variant: MD3CardVariant = .filled, cornerRadius: CGFloat = LassoRadius.lg.rawValue) {
        self.variant = variant
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(shape)
            .overlay(border)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var background: some View {
        ZStack {
            switch variant {
            case .elevated:
                scheme.surface
                scheme.surfaceTint.opacity(MD3Elevation.level1.tintOpacity)
            case .filled:
                scheme.surfaceContainerHigh
            case .outlined:
                scheme.surface
            }
        }
    }

    @ViewBuilder
    private var border: some View {
        switch variant {
        case .outlined:
            shape.stroke(scheme.outlineVariant.opacity(0.5), lineWidth: 0.5)
        default:
            EmptyView()
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .elevated: Color.black.opacity(0.10)
        case .outlined: Color.black.opacity(0.06)
        case .filled:   Color.black.opacity(0.04)
        }
    }

    private var shadowRadius: CGFloat {
        switch variant {
        case .elevated: 8
        case .outlined: 4
        case .filled:   2
        }
    }

    private var shadowY: CGFloat {
        switch variant {
        case .elevated: 3
        case .outlined: 2
        case .filled:   1
        }
    }
}

extension View {
    /// Wraps the view in an MD3 card.
    public func md3Card(_ variant: MD3CardVariant = .filled, cornerRadius: CGFloat = LassoRadius.lg.rawValue) -> some View {
        modifier(MD3CardModifier(variant, cornerRadius: cornerRadius))
    }
}

// MARK: - Section Card

/// A reusable MD3 card with a header and content area.
///
/// Replaces `OverviewSectionCard`, `sectionCard()`, `formCard()`, and `HelpSectionCard`.
public struct MD3SectionCard<Content: View>: View {

    @Environment(\.md3Scheme) private var scheme

    private let title: String
    private let icon: String?
    private let titleColor: Color?
    private let variant: MD3CardVariant
    @ViewBuilder private let content: () -> Content

    public init(
        _ title: String,
        icon: String? = nil,
        titleColor: Color? = nil,
        variant: MD3CardVariant = .outlined,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.titleColor = titleColor
        self.variant = variant
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — no background, just text with bottom spacing
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(MD3Typography.labelLarge)
                        .foregroundStyle(resolvedTitleColor)
                }
                Text(title)
                    .font(MD3Typography.titleSmall)
                    .foregroundStyle(resolvedTitleColor)
                Spacer()
            }
            .padding(.horizontal, LassoSpacing.md.rawValue)
            .padding(.top, LassoSpacing.md.rawValue)
            .padding(.bottom, LassoSpacing.sm.rawValue)

            // Subtle separator
            Rectangle()
                .fill(scheme.outlineVariant.opacity(0.3))
                .frame(height: 0.5)
                .padding(.horizontal, LassoSpacing.md.rawValue)

            // Content with proper padding
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, LassoSpacing.md.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
        }
        .md3Card(variant)
    }

    private var resolvedTitleColor: Color {
        titleColor ?? scheme.onSurfaceVariant
    }
}
