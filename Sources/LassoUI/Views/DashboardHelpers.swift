import SwiftUI
import LassoCore
import LassoData

// MARK: - Sidebar Item

enum SidebarItem: Hashable {
    case overview
    case containers
    case container(String)
    case images
    case volumes
    case networking
    case help
    case settings
}

// MARK: - Shared view helpers

func relativeDate(_ date: Date?) -> String {
    guard let date else { return "\u{2014}" }
    let seconds = Int(-date.timeIntervalSinceNow)
    if seconds < 60   { return "Just now" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    if seconds < 86400 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86400)d ago"
}

func stateColor(_ state: ContainerState, scheme: MD3ColorScheme) -> Color {
    switch state {
    case .running:                        scheme.success
    case .stopped, .deleted:              scheme.onSurfaceVariant
    case .error:                          scheme.error
    case .creating, .created, .starting:  scheme.primary
    case .stopping, .deleting:            scheme.warning
    }
}

func formatBytes(_ bytes: UInt64) -> String {
    let kb = Double(bytes) / 1024
    let mb = kb / 1024
    let gb = mb / 1024
    if gb >= 1 { return String(format: "%.1f GB", gb) }
    if mb >= 1 { return String(format: "%.1f MB", mb) }
    if kb >= 1 { return String(format: "%.1f KB", kb) }
    return "\(bytes) B"
}

func placeholderDetail(icon: String, title: String, subtitle: String = "", scheme: MD3ColorScheme) -> some View {
    VStack(spacing: LassoSpacing.md.rawValue) {
        Image(systemName: icon)
            .font(.system(size: 48))
            .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
        Text(title)
            .font(MD3Typography.headlineSmall)
            .foregroundStyle(scheme.onSurface)
        if !subtitle.isEmpty {
            Text(subtitle)
                .font(MD3Typography.bodyMedium)
                .foregroundStyle(scheme.onSurfaceVariant)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

@MainActor func actionButton(icon: String, scheme: MD3ColorScheme, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: icon)
            .font(MD3Typography.labelMedium)
            .foregroundStyle(scheme.onSecondaryContainer)
            .frame(width: 28, height: 28)
            .background(scheme.secondaryContainer)
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue, style: .continuous))
    }
    .buttonStyle(.plain)
    .pointerStyle(.link)
}
