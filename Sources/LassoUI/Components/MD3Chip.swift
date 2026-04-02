import SwiftUI

// MARK: - Filter Chip

/// An MD3 filter chip — toggles between outlined (unselected) and tonal filled (selected).
public struct MD3FilterChip: View {

    @Environment(\.md3Scheme) private var scheme
    private let label: String
    private let icon: String?
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(MD3Typography.labelMedium)
                }
                Text(label)
                    .font(MD3Typography.labelMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? scheme.secondaryContainer : scheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : scheme.outlineVariant.opacity(0.6), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

