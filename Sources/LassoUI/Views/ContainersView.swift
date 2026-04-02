import SwiftUI
import AppKit
import LassoCore
import LassoData

struct ContainersView: View {

    @Bindable var viewModel: DashboardViewModel
    let engine: any LassoContainerEngine
    let onNewContainer: () -> Void
    let onSelectContainer: (String) -> Void

    @Environment(\.md3Scheme) private var scheme

    private let portsWidth: CGFloat  = 160
    private let statusWidth: CGFloat  = 90
    private let startedWidth: CGFloat = 110
    private let actionsWidth: CGFloat = 110
    @State private var hoveredID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Spacer()
                Button {
                    Task { await viewModel.loadContainers() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(MD3ButtonStyle(.tonal))
                .disabled(viewModel.isLoading)
                .help("Refresh")
                Button {
                    Task { await viewModel.pruneContainers() }
                } label: {
                    Image(systemName: "trash.slash")
                }
                .buttonStyle(MD3ButtonStyle(.tonal))
                .help("Remove all stopped containers")
                Button { onNewContainer() } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(MD3ButtonStyle(.filled))
            }
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.md.rawValue)
            .background(scheme.surface)
            .overlay(alignment: .bottom) { Divider() }

            // Column headers
            HStack {
                Text("NAME").frame(maxWidth: .infinity, alignment: .leading)
                Text("PORTS").frame(width: portsWidth, alignment: .leading)
                Text("STATUS").frame(width: statusWidth, alignment: .leading)
                Text("STARTED").frame(width: startedWidth, alignment: .leading)
                Spacer().frame(width: actionsWidth)
            }
            .font(MD3Typography.labelSmall)
            .tracking(0.6)
            .foregroundStyle(scheme.onSurfaceVariant)
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .background(scheme.surfaceContainerLow)
            .overlay(alignment: .bottom) { Divider() }

            // Rows
            if viewModel.filteredContainers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredContainers) { container in
                            containerRow(container)
                            Divider().padding(.leading, LassoSpacing.lg.rawValue)
                        }
                    }
                }
                .background(scheme.surface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(scheme.surfaceContainerLowest)
    }

    // MARK: - Row

    private func containerRow(_ container: ContainerInfo) -> some View {
        let isHovered = hoveredID == container.id
        let isBuildKit = container.spec.name == "buildkit"
        return HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: isBuildKit ? "applelogo" : "shippingbox.fill")
                    .foregroundStyle(isBuildKit ? scheme.onSurface : scheme.primary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(container.spec.name)
                            .font(MD3Typography.bodyLarge)
                            .foregroundStyle(scheme.onSurface)
                            .lineLimit(1)
                        if isBuildKit {
                            Text("Apple\u{00AE}\u{2019}s Image Builder")
                                .font(MD3Typography.labelSmall)
                                .foregroundStyle(scheme.onSurfaceVariant)
                                .lineLimit(1)
                        }
                    }
                    Text(shortImageName(container.spec.image))
                        .font(.caption.monospaced())
                        .foregroundStyle(scheme.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            portCell(container.spec.networking.portMappings)
                .frame(width: portsWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .center)

            StatusBadge(state: container.state)
                .frame(width: statusWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .center)

            Text(relativeDate(container.createdAt))
                .font(MD3Typography.bodyMedium)
                .foregroundStyle(scheme.onSurfaceVariant)
                .frame(width: startedWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .center)

            HStack(spacing: 4) {
                if container.state == .stopped || container.state == .created {
                    actionButton(icon: "play.fill", scheme: scheme) {
                        Task {
                            do { try await engine.start(containerID: container.id) }
                            catch { viewModel.errorMessage = error.localizedDescription }
                            await viewModel.loadContainers()
                        }
                    }
                }
                if container.state == .running {
                    actionButton(icon: "stop.fill", scheme: scheme) {
                        Task {
                            do { try await engine.stop(containerID: container.id, timeout: .seconds(10)) }
                            catch { viewModel.errorMessage = error.localizedDescription }
                            await viewModel.loadContainers()
                        }
                    }
                }
                actionButton(icon: "arrow.up.right.square", scheme: scheme) {
                    onSelectContainer(container.id)
                }
                actionButton(icon: "trash", scheme: scheme) {
                    Task {
                        do { try await engine.delete(containerID: container.id) }
                        catch { viewModel.errorMessage = error.localizedDescription }
                        await viewModel.loadContainers()
                    }
                }
            }
            .opacity(isHovered ? 1 : 0)
            .frame(width: actionsWidth, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, LassoSpacing.sm.rawValue)
        .background(isHovered ? scheme.primary.opacity(0.08) : scheme.surface)
        .contentShape(Rectangle())
        .onHover { hoveredID = $0 ? container.id : nil }
        .onTapGesture { onSelectContainer(container.id) }
        .pointerStyle(.link)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    // MARK: - Helpers

    private func shortImageName(_ reference: String) -> String {
        let path = reference.split(separator: "/").last.map(String.init) ?? reference
        return path
    }

    // MARK: - Port cell

    @ViewBuilder
    private func portCell(_ ports: [PortMapping]) -> some View {
        if ports.isEmpty {
            Text("\u{2014}")
                .font(MD3Typography.bodyMedium)
                .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(ports.prefix(2), id: \.hostPort) { p in
                    HStack(spacing: 4) {
                        Text(p.proto.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(p.proto.lowercased() == "udp" ? scheme.warning : scheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (p.proto.lowercased() == "udp" ? scheme.warningContainer : scheme.primaryContainer)
                            )
                            .clipShape(Capsule())
                        HStack(spacing: 3) {
                            Text(String(p.containerPort))
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(scheme.onSurfaceVariant)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
                            Text("localhost:\(String(p.hostPort))")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(scheme.primary)
                                .underline()
                                .onTapGesture {
                                    if let url = URL(string: "http://localhost:\(p.hostPort)") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .pointerStyle(.link)
                        }
                    }
                }
                if ports.count > 2 {
                    Text("+\(ports.count - 2) more")
                        .font(MD3Typography.labelSmall)
                        .foregroundStyle(scheme.onSurfaceVariant)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: LassoSpacing.md.rawValue) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
            Text("No containers")
                .font(MD3Typography.headlineSmall)
                .foregroundStyle(scheme.onSurface)
            Text("Click \"New container\" to get started.")
                .font(MD3Typography.bodyMedium)
                .foregroundStyle(scheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
