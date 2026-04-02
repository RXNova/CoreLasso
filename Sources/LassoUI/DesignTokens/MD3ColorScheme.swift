import SwiftUI

// MARK: - MD3 Color Scheme

/// Material Design 3 color scheme with all 29 key color roles.
///
/// Pre-computed tonal palettes derived from seed blue `#1976D2`.
/// Use `MD3ColorScheme.light()` or `MD3ColorScheme.dark()` to obtain a scheme,
/// or read it from the environment via `@Environment(\.md3Scheme)`.
public struct MD3ColorScheme: Sendable {

    // MARK: Primary

    public let primary: Color
    public let onPrimary: Color
    public let primaryContainer: Color
    public let onPrimaryContainer: Color

    // MARK: Secondary

    public let secondary: Color
    public let onSecondary: Color
    public let secondaryContainer: Color
    public let onSecondaryContainer: Color

    // MARK: Tertiary

    public let tertiary: Color
    public let onTertiary: Color
    public let tertiaryContainer: Color
    public let onTertiaryContainer: Color

    // MARK: Error

    public let error: Color
    public let onError: Color
    public let errorContainer: Color
    public let onErrorContainer: Color

    // MARK: Surface

    public let surface: Color
    public let onSurface: Color
    public let surfaceVariant: Color
    public let onSurfaceVariant: Color

    // MARK: Surface Containers

    public let surfaceContainerLowest: Color
    public let surfaceContainerLow: Color
    public let surfaceContainer: Color
    public let surfaceContainerHigh: Color
    public let surfaceContainerHighest: Color

    // MARK: Outline

    public let outline: Color
    public let outlineVariant: Color

    // MARK: Inverse

    public let inverseSurface: Color
    public let inverseOnSurface: Color
    public let inversePrimary: Color

    // MARK: Surface Tint

    public let surfaceTint: Color

    // MARK: Semantic aliases (for convenience)

    public let success: Color
    public let onSuccess: Color
    public let successContainer: Color
    public let onSuccessContainer: Color

    public let warning: Color
    public let onWarning: Color
    public let warningContainer: Color
    public let onWarningContainer: Color
}

// MARK: - Light & Dark Factories

extension MD3ColorScheme {

    /// Light scheme derived from seed blue `#1976D2`.
    public static func light() -> MD3ColorScheme {
        MD3ColorScheme(
            // Primary — Blue tonal palette
            primary:                Color(hex: 0x1960A6),
            onPrimary:              Color(hex: 0xFFFFFF),
            primaryContainer:       Color(hex: 0xD3E4FF),
            onPrimaryContainer:     Color(hex: 0x001C3A),

            // Secondary — desaturated blue
            secondary:              Color(hex: 0x545F70),
            onSecondary:            Color(hex: 0xFFFFFF),
            secondaryContainer:     Color(hex: 0xD8E3F8),
            onSecondaryContainer:   Color(hex: 0x111C2B),

            // Tertiary — teal/cyan complement
            tertiary:               Color(hex: 0x6D5E78),
            onTertiary:             Color(hex: 0xFFFFFF),
            tertiaryContainer:      Color(hex: 0xF5E0FF),
            onTertiaryContainer:    Color(hex: 0x271B31),

            // Error
            error:                  Color(hex: 0xBA1A1A),
            onError:                Color(hex: 0xFFFFFF),
            errorContainer:         Color(hex: 0xFFDAD6),
            onErrorContainer:       Color(hex: 0x410002),

            // Surface — pushed apart for visible contrast
            surface:                Color(hex: 0xFFFFFF),
            onSurface:              Color(hex: 0x191C20),
            surfaceVariant:         Color(hex: 0xDADCE5),
            onSurfaceVariant:       Color(hex: 0x434750),

            // Surface Containers — page bg is noticeably gray so white cards pop
            surfaceContainerLowest: Color(hex: 0xF0F1F6),
            surfaceContainerLow:    Color(hex: 0xEAEBF0),
            surfaceContainer:       Color(hex: 0xE4E5EB),
            surfaceContainerHigh:   Color(hex: 0xDEDFE5),
            surfaceContainerHighest:Color(hex: 0xD6D7DD),

            // Outline
            outline:                Color(hex: 0x737780),
            outlineVariant:         Color(hex: 0xB8BBC4),

            // Inverse
            inverseSurface:         Color(hex: 0x2E3135),
            inverseOnSurface:       Color(hex: 0xF0F0F7),
            inversePrimary:         Color(hex: 0xA3C9FE),

            // Surface Tint
            surfaceTint:            Color(hex: 0x1960A6),

            // Semantic: Success — green tonal
            success:                Color(hex: 0x386A20),
            onSuccess:              Color(hex: 0xFFFFFF),
            successContainer:       Color(hex: 0xB8F397),
            onSuccessContainer:     Color(hex: 0x062100),

            // Semantic: Warning — orange tonal
            warning:                Color(hex: 0x8B5000),
            onWarning:              Color(hex: 0xFFFFFF),
            warningContainer:       Color(hex: 0xFFDCBE),
            onWarningContainer:     Color(hex: 0x2C1600)
        )
    }

    /// Dark scheme derived from seed blue `#1976D2`.
    public static func dark() -> MD3ColorScheme {
        MD3ColorScheme(
            // Primary
            primary:                Color(hex: 0xA3C9FE),
            onPrimary:              Color(hex: 0x00315E),
            primaryContainer:       Color(hex: 0x004885),
            onPrimaryContainer:     Color(hex: 0xD3E4FF),

            // Secondary
            secondary:              Color(hex: 0xBCC7DB),
            onSecondary:            Color(hex: 0x263141),
            secondaryContainer:     Color(hex: 0x3D4758),
            onSecondaryContainer:   Color(hex: 0xD8E3F8),

            // Tertiary
            tertiary:               Color(hex: 0xD9C2E5),
            onTertiary:             Color(hex: 0x3D3047),
            tertiaryContainer:      Color(hex: 0x55465F),
            onTertiaryContainer:    Color(hex: 0xF5E0FF),

            // Error
            error:                  Color(hex: 0xFFB4AB),
            onError:                Color(hex: 0x690005),
            errorContainer:         Color(hex: 0x93000A),
            onErrorContainer:       Color(hex: 0xFFDAD6),

            // Surface
            surface:                Color(hex: 0x111418),
            onSurface:              Color(hex: 0xE2E2E9),
            surfaceVariant:         Color(hex: 0x434750),
            onSurfaceVariant:       Color(hex: 0xC3C6CF),

            // Surface Containers
            surfaceContainerLowest: Color(hex: 0x0C0E13),
            surfaceContainerLow:    Color(hex: 0x191C20),
            surfaceContainer:       Color(hex: 0x1D2024),
            surfaceContainerHigh:   Color(hex: 0x282A2F),
            surfaceContainerHighest:Color(hex: 0x33353A),

            // Outline
            outline:                Color(hex: 0x8D9199),
            outlineVariant:         Color(hex: 0x434750),

            // Inverse
            inverseSurface:         Color(hex: 0xE2E2E9),
            inverseOnSurface:       Color(hex: 0x2E3135),
            inversePrimary:         Color(hex: 0x1960A6),

            // Surface Tint
            surfaceTint:            Color(hex: 0xA3C9FE),

            // Semantic: Success
            success:                Color(hex: 0x9DD67E),
            onSuccess:              Color(hex: 0x103800),
            successContainer:       Color(hex: 0x215107),
            onSuccessContainer:     Color(hex: 0xB8F397),

            // Semantic: Warning
            warning:                Color(hex: 0xFFB870),
            onWarning:              Color(hex: 0x4A2800),
            warningContainer:       Color(hex: 0x6A3C00),
            onWarningContainer:     Color(hex: 0xFFDCBE)
        )
    }
}

// MARK: - Environment Integration

private struct MD3SchemeKey: EnvironmentKey {
    static let defaultValue: MD3ColorScheme = .light()
}

extension EnvironmentValues {
    /// The active Material Design 3 color scheme.
    public var md3Scheme: MD3ColorScheme {
        get { self[MD3SchemeKey.self] }
        set { self[MD3SchemeKey.self] = newValue }
    }
}

extension View {
    /// Injects the appropriate MD3 color scheme based on the system appearance.
    public func md3Themed() -> some View {
        modifier(MD3ThemeModifier())
    }
}

private struct MD3ThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.md3Scheme, colorScheme == .dark ? .dark() : .light())
    }
}

// MARK: - Color(hex:) Helper

extension Color {
    /// Creates a `Color` from a 24-bit hex integer, e.g. `Color(hex: 0x1976D2)`.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
