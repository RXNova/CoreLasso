import SwiftUI
import LassoCore

/// A Material Design 3 chip displaying a container's lifecycle state.
public struct StatusBadge: View {

    @Environment(\.md3Scheme) private var scheme
    private let state: ContainerState
    @State private var pulsing = false

    public init(state: ContainerState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 5) {
            ZStack {
                if state == .running {
                    Circle()
                        .fill(tagColor.opacity(0.35))
                        .frame(width: 10, height: 10)
                        .scaleEffect(pulsing ? 1.0 : 0.55)
                        .opacity(pulsing ? 0.0 : 0.7)
                        .animation(
                            .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                            value: pulsing
                        )
                }
                Circle()
                    .fill(tagColor)
                    .frame(width: 7, height: 7)
            }
            Text(label)
                .font(MD3Typography.labelMedium)
                .foregroundStyle(tagColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tagBackground)
        .clipShape(Capsule())
        .onAppear { if state == .running { pulsing = true } }
        .onChange(of: state) { _, new in pulsing = (new == .running) }
    }

    // MARK: - Helpers

    private var tagColor: Color {
        switch state {
        case .running:                        scheme.success
        case .stopped, .deleted:              scheme.onSurfaceVariant
        case .error:                          scheme.error
        case .creating, .created, .starting:  scheme.primary
        case .stopping, .deleting:            scheme.warning
        }
    }

    private var tagBackground: Color {
        switch state {
        case .running:                        scheme.successContainer
        case .stopped, .deleted:              scheme.surfaceContainerHighest
        case .error:                          scheme.errorContainer
        case .creating, .created, .starting:  scheme.primaryContainer
        case .stopping, .deleting:            scheme.warningContainer
        }
    }

    private var label: String {
        switch state {
        case .creating:  "Creating"
        case .created:   "Created"
        case .starting:  "Starting"
        case .running:   "Running"
        case .stopping:  "Stopping"
        case .stopped:   "Stopped"
        case .deleting:  "Deleting"
        case .deleted:   "Deleted"
        case .error:     "Error"
        }
    }
}
