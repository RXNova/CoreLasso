import SwiftUI
import LassoCore

/// A Material Design chip displaying a container's lifecycle state.
public struct StatusBadge: View {

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
                .font(.caption.weight(.medium))
                .foregroundStyle(tagColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tagBackground)
        .clipShape(Capsule())
        .onAppear { if state == .running { pulsing = true } }
        .onChange(of: state) { _, new in pulsing = (new == .running) }
    }

    // MARK: - Helpers

    private var tagColor: Color {
        switch state {
        case .running:                        LassoColors.antSuccess
        case .stopped, .deleted:              LassoColors.antTextSecondary
        case .error:                          LassoColors.antError
        case .creating, .created, .starting:  LassoColors.antBlue
        case .stopping, .deleting:            LassoColors.antWarning
        }
    }

    private var tagBackground: Color {
        switch state {
        case .running:                        LassoColors.antSuccessBg
        case .stopped, .deleted:              Color(white: 0.93)
        case .error:                          LassoColors.antErrorBg
        case .creating, .created, .starting:  LassoColors.antBlueBg
        case .stopping, .deleting:            LassoColors.antWarningBg
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
