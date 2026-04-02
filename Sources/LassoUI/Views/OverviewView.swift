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
public struct OverviewView: View {

    let viewModel: DashboardViewModel
    let engine: any LassoContainerEngine
    let onNewContainer: () -> Void
    let onPullImage: () -> Void
    let onSelectContainer: (String) -> Void
    let onNavigate: (OverviewDestination) -> Void

    @Environment(\.md3Scheme) private var scheme

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
        .background(scheme.surfaceContainerLowest.ignoresSafeArea())
    }

    // MARK: - Stat Card

    private var totalContainers: Int { viewModel.containers.count }

    private let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    private var statCards: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top: gradient hero with running count ────────────────────
            ZStack {
                LinearGradient(
                    colors: [
                        scheme.primary,
                        scheme.primary.opacity(0.75),
                        scheme.tertiary.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 180, height: 180)
                    .offset(x: -40, y: 50)
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 120, height: 120)
                    .offset(x: 280, y: -30)

                // Content
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Containers")
                            .font(MD3Typography.labelLarge)
                            .foregroundStyle(Color.white.opacity(0.7))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(running.count)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text("running")
                                .font(MD3Typography.titleMedium)
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        miniStat("\(totalContainers)", label: "total", icon: "shippingbox.fill")
                        miniStat("\(stopped.count)", label: "stopped", icon: "stop.circle")
                        if !errored.isEmpty {
                            miniStat("\(errored.count)", label: "error", icon: "exclamationmark.triangle.fill")
                        }
                    }
                }
                .padding(LassoSpacing.lg.rawValue)
            }
            .frame(height: 130)
            .onTapGesture { onNavigate(.containers) }
            .pointerStyle(.link)

            // ── White bottom half ───────────────────────────────────────
            VStack(spacing: 0) {
                // State bar
                if totalContainers > 0 {
                    stateBar
                        .padding(.horizontal, LassoSpacing.lg.rawValue)
                        .padding(.top, LassoSpacing.md.rawValue)
                        .padding(.bottom, LassoSpacing.sm.rawValue)
                }

                // Resource counters
                HStack(spacing: 0) {
                    resourceCounter(
                        icon: "square.stack.3d.up.fill",
                        value: viewModel.images.count,
                        label: "Images",
                        color: scheme.primary,
                        containerColor: scheme.primaryContainer
                    ) { onNavigate(.images) }

                    resourceDivider

                    resourceCounter(
                        icon: "network",
                        value: viewModel.networks.count,
                        label: "Networks",
                        color: scheme.tertiary,
                        containerColor: scheme.tertiaryContainer
                    ) { onNavigate(.networking) }

                    resourceDivider

                    resourceCounter(
                        icon: "cylinder.split.1x2.fill",
                        value: viewModel.volumes.count,
                        label: "Volumes",
                        color: scheme.warning,
                        containerColor: scheme.warningContainer
                    ) { onNavigate(.volumes) }
                }
                .padding(.horizontal, LassoSpacing.sm.rawValue)
                .padding(.bottom, LassoSpacing.md.rawValue)
                .padding(.top, totalContainers > 0 ? 0 : LassoSpacing.md.rawValue)
            }
            .background(scheme.surface)
        }
        .clipShape(cardShape)
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 3)
    }

    // MARK: - Stat Card Subviews

    private func miniStat(_ value: String, label: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundStyle(Color.white.opacity(0.8))
    }

    private var stateBar: some View {
        GeometryReader { geo in
            let total = max(totalContainers, 1)
            let runW = geo.size.width * CGFloat(running.count) / CGFloat(total)
            let stopW = geo.size.width * CGFloat(stopped.count) / CGFloat(total)
            let errW = geo.size.width * CGFloat(errored.count) / CGFloat(total)
            let otherW = geo.size.width - runW - stopW - errW

            HStack(spacing: 2) {
                if running.count > 0 {
                    Capsule().fill(scheme.success)
                        .frame(width: max(runW, 4))
                }
                if stopped.count > 0 {
                    Capsule().fill(scheme.onSurfaceVariant.opacity(0.35))
                        .frame(width: max(stopW, 4))
                }
                if errored.count > 0 {
                    Capsule().fill(scheme.error)
                        .frame(width: max(errW, 4))
                }
                if otherW > 1 {
                    Capsule().fill(scheme.primary.opacity(0.25))
                        .frame(width: max(otherW, 4))
                }
            }
        }
        .frame(height: 6)
    }

    private func resourceCounter(
        icon: String,
        value: Int,
        label: String,
        color: Color,
        containerColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(containerColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(scheme.onSurface)
                    .contentTransition(.numericText())
                Text(label)
                    .font(MD3Typography.labelSmall)
                    .foregroundStyle(scheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, LassoSpacing.sm.rawValue)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    private var resourceDivider: some View {
        Rectangle()
            .fill(scheme.outlineVariant.opacity(0.25))
            .frame(width: 0.5, height: 44)
    }

    // MARK: - Container sections

    private var errorSection: some View {
        MD3SectionCard(
            "Needs Attention",
            icon: "exclamationmark.triangle.fill",
            titleColor: scheme.error
        ) {
            containerRows(errored)
        }
    }

    private var stoppedSection: some View {
        MD3SectionCard(
            "Stopped",
            icon: "stop.circle",
            titleColor: scheme.onSurfaceVariant
        ) {
            containerRows(Array(stopped.prefix(3)))
            if stopped.count > 3 {
                Button {
                    onNavigate(.containers)
                } label: {
                    Text("View all \(stopped.count) stopped containers \u{2192}")
                        .font(MD3Typography.labelMedium)
                        .foregroundStyle(scheme.primary)
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
                .fill(stateColor(container.state, scheme: scheme))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.spec.name)
                    .font(MD3Typography.bodyLarge)
                    .foregroundStyle(scheme.onSurface)
                    .lineLimit(1)
                Text(container.spec.image)
                    .font(MD3Typography.bodySmall)
                    .foregroundStyle(scheme.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer()
            if let first = container.spec.networking.portMappings.first {
                Text(":\(first.hostPort)")
                    .font(.caption.monospaced())
                    .foregroundStyle(scheme.onSurfaceVariant.opacity(0.6))
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
                .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
            Text("No containers yet")
                .font(MD3Typography.headlineSmall)
                .foregroundStyle(scheme.onSurface)
            Text("Create your first container to get started.")
                .font(MD3Typography.bodyMedium)
                .foregroundStyle(scheme.onSurfaceVariant)
            Button {
                onNewContainer()
            } label: {
                Label("New Container", systemImage: "plus")
            }
            .buttonStyle(MD3ButtonStyle(.filled))
            .padding(.top, LassoSpacing.xs.rawValue)
        }
        .frame(maxWidth: .infinity)
        .padding(LassoSpacing.xl.rawValue)
        .md3Card(.outlined)
    }
}
