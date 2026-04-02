import SwiftUI

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

/// Corner-radius tokens — Material Design 3 shape scale.
public enum LassoRadius: CGFloat {
    /// Extra Small — 4pt (buttons, small chips).
    case sm = 4
    /// Small — 8pt (chips, small cards).
    case md = 8
    /// Medium — 12pt (cards, dialogs).
    case lg = 12
    /// Large — 16pt (large cards).
    case xl = 16
}
