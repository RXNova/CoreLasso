import SwiftUI
import LassoCore

// MARK: - Overview Destination

public enum OverviewDestination {
    case containers
    case images
    case volumes
    case networking
}

// MARK: - Overview View

/// Landing tab — shown by default when the app opens.
/// Displays at-a-glance summary cards, live container lists, and quick actions.
public struct OverviewView: View {

    let viewModel: DashboardViewModel
    let engine: any LassoContainerEngine
    let onNewContainer: () -> Void
    let onPullImage: () -> Void
    let onSelectContainer: (String) -> Void
    let onNavigate: (OverviewDestination) -> Void

    // MARK: - Derived state

    private var running: [ContainerInfo] {
        viewModel.containers.filter { $0.state == .running }
    }
    private var stopped: [ContainerInfo] {
        viewModel.containers.filter { $0.state == .stopped || $0.state == .created }
    }
    private var errored: [ContainerInfo] {
        viewModel.containers.filter { $0.state == .error }
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LassoSpacing.lg.rawValue) {
                header
                statCards

                if !errored.isEmpty {
                    errorSection
                }

                ResourceChartsView(
                    engine: engine,
                    runningContainers: running,
                    volumes: viewModel.volumes
                )

                if !stopped.isEmpty {
                    stoppedSection
                }
                if viewModel.containers.isEmpty && !viewModel.isLoading {
                    emptyState
                }
            }
            .padding(LassoSpacing.lg.rawValue)
        }
        .background(LassoColors.antPageBg.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: LassoSpacing.sm.rawValue) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Overview")
                    .font(.title2.bold())
                    .foregroundStyle(LassoColors.antTextPrimary)
                Text("Container Runtime")
                    .font(.subheadline)
                    .foregroundStyle(LassoColors.antTextSecondary)
            }
            Spacer()
            engineBadge
        }
    }

    private var engineBadge: some View {
        let isVZ = viewModel.engineLabel.contains("VZ") || viewModel.engineLabel.contains("Direct")
        return HStack(spacing: 4) {
            Image(systemName: isVZ ? "cpu" : "terminal")
            Text(viewModel.engineLabel)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(LassoColors.antBlueBg)
        .foregroundStyle(LassoColors.antBlue)
        .clipShape(Capsule())
    }

    // MARK: - Stat Cards

    private var statCards: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "play.circle.fill",
                label: "Running",
                value: running.count,
                color: LassoColors.antSuccess
            ) { onNavigate(.containers) }

            statDivider

            statItem(
                icon: "stop.circle.fill",
                label: "Stopped",
                value: stopped.count,
                color: LassoColors.antTextSecondary
            ) { onNavigate(.containers) }

            statDivider

            statItem(
                icon: "exclamationmark.triangle.fill",
                label: "Error",
                value: errored.count,
                color: LassoColors.antError
            ) { onNavigate(.containers) }

            statDivider

            statItem(
                icon: "square.stack.3d.up.fill",
                label: "Images",
                value: viewModel.images.count,
                color: LassoColors.antBlue
            ) { onNavigate(.images) }

            statDivider

            statItem(
                icon: "network",
                label: "Networks",
                value: viewModel.networks.count,
                color: Color(hue: 0.75, saturation: 0.5, brightness: 0.75)
            ) { onNavigate(.networking) }

            statDivider

            statItem(
                icon: "cylinder.split.1x2.fill",
                label: "Volumes",
                value: viewModel.volumes.count,
                color: Color.orange
            ) { onNavigate(.volumes) }
        }
        .padding(.vertical, LassoSpacing.md.rawValue)
        .background(LassoColors.antCardBg)
        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue))
        .overlay(
            RoundedRectangle(cornerRadius: LassoRadius.md.rawValue)
                .stroke(LassoColors.antBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
    }

    private func statItem(
        icon: String,
        label: String,
        value: Int,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(LassoColors.antTextPrimary)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LassoColors.antTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private var statDivider: some View {
        Divider()
            .frame(height: 48)
            .padding(.horizontal, 2)
    }

    // MARK: - Container sections

    private var errorSection: some View {
        OverviewSectionCard(
            title: "Needs Attention",
            icon: "exclamationmark.triangle.fill",
            titleColor: LassoColors.antError
        ) {
            containerRows(errored)
        }
    }

    private var stoppedSection: some View {
        OverviewSectionCard(
            title: "Stopped",
            icon: "stop.circle",
            titleColor: LassoColors.antTextSecondary
        ) {
            containerRows(Array(stopped.prefix(3)))
            if stopped.count > 3 {
                Button {
                    onNavigate(.containers)
                } label: {
                    Text("View all \(stopped.count) stopped containers →")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(LassoColors.antBlue)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .padding(.vertical, LassoSpacing.xs.rawValue)
            }
        }
    }

    // MARK: - Container row list builder

    @ViewBuilder
    private func containerRows(_ items: [ContainerInfo]) -> some View {
        ForEach(items) { container in
            containerRow(container)
            if container.id != items.last?.id {
                Divider().padding(.leading, 32)
            }
        }
    }

    private func containerRow(_ container: ContainerInfo) -> some View {
        HStack(spacing: LassoSpacing.sm.rawValue) {
            Circle()
                .fill(stateColor(container.state))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.spec.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(LassoColors.antTextPrimary)
                    .lineLimit(1)
                Text(container.spec.image)
                    .font(.caption)
                    .foregroundStyle(LassoColors.antTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if let first = container.spec.networking.portMappings.first {
                Text(":\(first.hostPort)")
                    .font(.caption.monospaced())
                    .foregroundStyle(LassoColors.antTextDisabled)
            }
            StatusBadge(state: container.state)
        }
        .padding(.vertical, LassoSpacing.sm.rawValue)
        .contentShape(Rectangle())
        .onTapGesture { onSelectContainer(container.id) }
        .pointerStyle(.link)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: LassoSpacing.md.rawValue) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(LassoColors.antTextDisabled)
            Text("No containers yet")
                .font(.title3.weight(.medium))
                .foregroundStyle(LassoColors.antTextPrimary)
            Text("Create your first container to get started.")
                .font(.subheadline)
                .foregroundStyle(LassoColors.antTextSecondary)
            Button {
                onNewContainer()
            } label: {
                Label("New Container", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(GlassButtonStyle(.primary))
            .padding(.top, LassoSpacing.xs.rawValue)
        }
        .frame(maxWidth: .infinity)
        .padding(LassoSpacing.xl.rawValue)
        .background(LassoColors.antCardBg)
        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue))
        .overlay(
            RoundedRectangle(cornerRadius: LassoRadius.md.rawValue)
                .stroke(LassoColors.antBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: LassoRadius.md.rawValue)
                .stroke(LassoColors.antBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func stateColor(_ state: ContainerState) -> Color {
        switch state {
        case .running:                        LassoColors.antSuccess
        case .stopped, .deleted:              LassoColors.antTextSecondary
        case .error:                          LassoColors.antError
        case .creating, .created, .starting:  LassoColors.antBlue
        case .stopping, .deleting:            LassoColors.antWarning
        }
    }
}

// MARK: - Section Card

struct OverviewSectionCard<Content: View>: View {
    let title: String
    var icon: String? = nil
    var titleColor: Color = LassoColors.antTextPrimary
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: LassoSpacing.xs.rawValue) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(titleColor)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(titleColor)
            }
            .padding(.horizontal, LassoSpacing.md.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LassoColors.arcTableHeader)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, LassoSpacing.md.rawValue)
        }
        .background(LassoColors.antCardBg)
        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue))
        .overlay(
            RoundedRectangle(cornerRadius: LassoRadius.md.rawValue)
                .stroke(LassoColors.antBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
    }
}
