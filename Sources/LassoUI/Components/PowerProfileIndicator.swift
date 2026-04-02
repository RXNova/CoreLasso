import SwiftUI
import LassoCore

/// An MD3-style badge displaying a container's power profile.
public struct PowerProfileIndicator: View {

    @Environment(\.md3Scheme) private var scheme
    private let profile: LassoPowerProfile

    public init(profile: LassoPowerProfile) {
        self.profile = profile
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: profile.symbolName)
                .font(MD3Typography.labelSmall)
            Text(profile.displayName)
                .font(MD3Typography.labelSmall)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(badgeBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeColor.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var badgeColor: Color {
        switch profile {
        case .utility:     scheme.success
        case .balanced:    scheme.primary
        case .performance: scheme.warning
        }
    }

    private var badgeBackground: Color {
        switch profile {
        case .utility:     scheme.successContainer
        case .balanced:    scheme.primaryContainer
        case .performance: scheme.warningContainer
        }
    }
}
