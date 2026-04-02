import SwiftUI

// MARK: - MD3 Elevation

/// Material Design 3 elevation levels.
///
/// Each level defines a surface-tint opacity and shadow parameters.
/// MD3 uses surface tint overlay (not just shadows) to communicate elevation.
public enum MD3Elevation: Int, CaseIterable, Sendable {
    case level0 = 0
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5

    /// Opacity of the `surfaceTint` color overlay at this elevation.
    public var tintOpacity: Double {
        switch self {
        case .level0: 0.0
        case .level1: 0.05
        case .level2: 0.08
        case .level3: 0.11
        case .level4: 0.12
        case .level5: 0.14
        }
    }

    /// Shadow blur radius.
    public var shadowRadius: CGFloat {
        switch self {
        case .level0: 0
        case .level1: 3
        case .level2: 6
        case .level3: 8
        case .level4: 10
        case .level5: 12
        }
    }

    /// Shadow Y offset.
    public var shadowY: CGFloat {
        switch self {
        case .level0: 0
        case .level1: 1
        case .level2: 2
        case .level3: 3
        case .level4: 4
        case .level5: 5
        }
    }
}
