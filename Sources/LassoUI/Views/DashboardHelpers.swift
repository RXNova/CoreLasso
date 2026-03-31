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
    guard let date else { return "—" }
    let seconds = Int(-date.timeIntervalSinceNow)
    if seconds < 60   { return "Just now" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    if seconds < 86400 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86400)d ago"
}

func stateColor(_ state: ContainerState) -> Color {
    switch state {
    case .running:                        LassoColors.antSuccess
    case .stopped, .deleted:              LassoColors.antTextSecondary
    case .error:                          LassoColors.antError
    case .creating, .created, .starting:  LassoColors.antBlue
    case .stopping, .deleting:            LassoColors.antWarning
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

func placeholderDetail(icon: String, title: String, subtitle: String = "") -> some View {
    VStack(spacing: LassoSpacing.md.rawValue) {
        Image(systemName: icon)
            .font(.system(size: 48))
            .foregroundStyle(LassoColors.antTextDisabled)
        Text(title)
            .font(.title3.weight(.medium))
            .foregroundStyle(LassoColors.antTextPrimary)
        if !subtitle.isEmpty {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(LassoColors.antTextSecondary)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

func engineBadge(label: String) -> some View {
    let isVZ = label.contains("VZ") || label.contains("Direct")
    return HStack(spacing: 4) {
        Image(systemName: isVZ ? "cpu" : "terminal")
        Text(label)
    }
    .font(.caption.weight(.semibold))
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
    .background(LassoColors.antBlueBg)
    .foregroundStyle(LassoColors.antBlue)
    .clipShape(Capsule())
}

func actionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 26, height: 26)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    .buttonStyle(.plain)
    .pointerStyle(.link)
}
