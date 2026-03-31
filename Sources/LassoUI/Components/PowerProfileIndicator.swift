import SwiftUI
import LassoCore

/// An Ant Design-style tag badge displaying a container's power profile.
public struct PowerProfileIndicator: View {

    private let profile: LassoPowerProfile

    public init(profile: LassoPowerProfile) {
        self.profile = profile
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: profile.symbolName)
                .font(.caption2)
            Text(profile.displayName)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, LassoSpacing.sm.rawValue)
        .padding(.vertical, 3)
        .background(badgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(badgeColor.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private var badgeColor: Color {
        switch profile {
        case .utility:     LassoColors.antSuccess
        case .balanced:    LassoColors.antBlue
        case .performance: LassoColors.antWarning
        }
    }

    private var badgeBackground: Color {
        switch profile {
        case .utility:     LassoColors.antSuccessBg
        case .balanced:    LassoColors.antBlueBg
        case .performance: LassoColors.antWarningBg
        }
    }
}
