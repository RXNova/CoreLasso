import SwiftUI
import LassoCore

// MARK: - Color Palette

/// Glassmorphic color tokens for the CoreLasso design system.
public enum LassoColors {

    /// Subtle white border used on glass surfaces.
    public static let glassBorder = Color.white.opacity(0.20)

    /// Translucent white fill for glass cards.
    public static let glassBackground = Color.white.opacity(0.08)

    /// Cool blue-green glow for the utility (E-Core) power profile.
    public static let utilityGlow = Color(hue: 0.55, saturation: 0.7, brightness: 0.9)

    /// Soft amber glow for the balanced (mixed) power profile.
    public static let balancedGlow = Color(hue: 0.12, saturation: 0.6, brightness: 0.95)

    /// Pulsing orange-red glow for the performance (P-Core) power profile.
    public static let performanceGlow = Color(hue: 0.03, saturation: 0.8, brightness: 0.95)

    /// Red glow indicating an error state.
    public static let errorGlow = Color.red

    /// Gray glow indicating a stopped container.
    public static let stoppedGlow = Color.gray

    // MARK: - Material Design 3 palette

    /// Material Blue 700 — primary accent.
    public static let antBlue          = Color(red: 0.098, green: 0.463, blue: 0.824)   // #1976D2
    /// Material Blue 50 — primary container / hover tint.
    public static let antBlueBg        = Color(red: 0.890, green: 0.949, blue: 0.992)   // #E3F2FD
    /// Material divider — rgba(0,0,0,0.12).
    public static let antBorder        = Color.black.opacity(0.12)
    /// Material Gray 100 — page canvas.
    public static let antPageBg        = Color(red: 0.961, green: 0.961, blue: 0.961)   // #F5F5F5
    public static let antCardBg        = Color.white
    /// rgba(0,0,0,0.87) — high-emphasis text.
    public static let antTextPrimary   = Color.black.opacity(0.87)
    /// rgba(0,0,0,0.60) — medium-emphasis text.
    public static let antTextSecondary = Color.black.opacity(0.60)
    /// rgba(0,0,0,0.38) — disabled text.
    public static let antTextDisabled  = Color.black.opacity(0.38)
    /// Material Green 700.
    public static let antSuccess       = Color(red: 0.220, green: 0.557, blue: 0.235)   // #388E3C
    /// Material Green 50.
    public static let antSuccessBg     = Color(red: 0.910, green: 0.961, blue: 0.914)   // #E8F5E9
    /// Material Orange 700.
    public static let antWarning       = Color(red: 0.961, green: 0.486, blue: 0.000)   // #F57C00
    /// Material Orange 50.
    public static let antWarningBg     = Color(red: 1.000, green: 0.953, blue: 0.878)   // #FFF3E0
    /// Material Red 700.
    public static let antError         = Color(red: 0.827, green: 0.184, blue: 0.184)   // #D32F2F
    /// Material Red 50.
    public static let antErrorBg       = Color(red: 1.000, green: 0.922, blue: 0.922)   // #FFEBEE

    // MARK: - Material surface tokens

    /// Pure white toolbar surface.
    public static let arcToolbar      = Color.white
    /// Gray 50 — table header rows.
    public static let arcTableHeader  = Color(red: 0.980, green: 0.980, blue: 0.980)   // #FAFAFA
    /// Gray 100 — filter/search bar.
    public static let arcFilterBar    = Color(red: 0.961, green: 0.961, blue: 0.961)   // #F5F5F5
    /// Unused — retained for binary compatibility.
    public static let arcGradientTop  = Color.clear
    public static let arcGradientBot  = Color.clear
}

// MARK: - Spacing Scale

/// Consistent spacing tokens used throughout the UI.
public enum LassoSpacing: CGFloat {
    case xs = 4
    case sm = 8
    case md = 16
    case lg = 24
    case xl = 32
}

// MARK: - Corner Radius Scale

/// Corner-radius tokens — Material Design scale.
public enum LassoRadius: CGFloat {
    case sm = 4
    case md = 8
    case lg = 12
    case xl = 16
}

// MARK: - Power Profile → Color

extension LassoPowerProfile {

    /// The glow `Color` associated with this power profile.
    public var glowColor: Color {
        switch self {
        case .utility:     LassoColors.utilityGlow
        case .balanced:    LassoColors.balancedGlow
        case .performance: LassoColors.performanceGlow
        }
    }
}

// MARK: - Container State → Color

extension ContainerState {

    /// The glow `Color` that represents this lifecycle state.
    ///
    /// For `.running`, the glow should be driven by the container's power profile
    /// instead — use `LassoPowerProfile.glowColor` in that case. This property
    /// returns green as a sensible default for running containers.
    public var glowColor: Color {
        switch self {
        case .running:              .green
        case .stopped, .deleted:    LassoColors.stoppedGlow
        case .error:                LassoColors.errorGlow
        case .creating, .created,
             .starting:             .blue
        case .stopping, .deleting:  .orange
        }
    }
}
