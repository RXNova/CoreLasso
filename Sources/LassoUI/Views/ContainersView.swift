import SwiftUI
import AppKit
import LassoCore
import LassoData

struct ContainersView: View {

    @Bindable var viewModel: DashboardViewModel
    let engine: any LassoContainerEngine
    let onNewContainer: () -> Void
    let onSelectContainer: (String) -> Void

    private let portsWidth: CGFloat  = 160
    private let statusWidth: CGFloat  = 90
    private let startedWidth: CGFloat = 110
    private let actionsWidth: CGFloat = 110
    @State private var hoveredID: String?

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────────────
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Text("Containers")
                    .font(.title2.bold())
                    .foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
                engineBadge(label: viewModel.engineLabel)
                Button {
                    Task { await viewModel.loadContainers() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(GlassButtonStyle(.secondary))
                .disabled(viewModel.isLoading)
                .help("Refresh")
                Button {
                    Task { await viewModel.pruneContainers() }
                } label: {
                    Image(systemName: "trash.slash")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(GlassButtonStyle(.secondary))
                .help("Remove all stopped containers")
                Button { onNewContainer() } label: {
                    Label("New", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(GlassButtonStyle(.primary))
            }
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.md.rawValue)
            .background(LassoColors.arcToolbar)
            .overlay(alignment: .bottom) { Divider() }

            // ── Column headers ───────────────────────────────────────────
            HStack {
                Text("NAME").frame(maxWidth: .infinity, alignment: .leading)
                Text("PORTS").frame(width: portsWidth, alignment: .leading)
                Text("STATUS").frame(width: statusWidth, alignment: .leading)
                Text("STARTED").frame(width: startedWidth, alignment: .leading)
                Spacer().frame(width: actionsWidth)
            }
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(LassoColors.antTextSecondary)
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .background(LassoColors.arcTableHeader)
            .overlay(alignment: .bottom) { Divider() }

            // ── Rows ─────────────────────────────────────────────────────
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
                .background(LassoColors.antCardBg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LassoColors.antPageBg)
    }

    // MARK: - Row

    private func containerRow(_ container: ContainerInfo) -> some View {
        let isHovered = hoveredID == container.id
        let isBuildKit = container.spec.name == "buildkit"
        return HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: isBuildKit ? "applelogo" : "shippingbox.fill")
                    .foregroundStyle(isBuildKit ? LassoColors.antTextPrimary : LassoColors.antBlue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(container.spec.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(LassoColors.antTextPrimary)
                            .lineLimit(1)
                        if isBuildKit {
                            Text("Apple\u{00AE}\u{2019}s Image Builder")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(LassoColors.antTextSecondary)
                                .lineLimit(1)
                        }
                    }
                    Text(shortImageName(container.spec.image))
                        .font(.caption.monospaced())
                        .foregroundStyle(LassoColors.antTextSecondary)
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
                .font(.body)
                .foregroundStyle(LassoColors.antTextSecondary)
                .frame(width: startedWidth, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .center)

            HStack(spacing: 4) {
                if container.state == .stopped || container.state == .created {
                    actionButton(icon: "play.fill", color: LassoColors.antSuccess) {
                        Task {
                            do { try await engine.start(containerID: container.id) }
                            catch { viewModel.errorMessage = error.localizedDescription }
                            await viewModel.loadContainers()
                        }
                    }
                }
                if container.state == .running {
                    actionButton(icon: "stop.fill", color: LassoColors.antWarning) {
                        Task {
                            do { try await engine.stop(containerID: container.id, timeout: .seconds(10)) }
                            catch { viewModel.errorMessage = error.localizedDescription }
                            await viewModel.loadContainers()
                        }
                    }
                }
                actionButton(icon: "arrow.up.right.square", color: LassoColors.antBlue) {
                    onSelectContainer(container.id)
                }
                actionButton(icon: "trash", color: LassoColors.antError) {
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
        .background(isHovered ? LassoColors.antBlueBg : LassoColors.antCardBg)
        .contentShape(Rectangle())
        .onHover { hoveredID = $0 ? container.id : nil }
        .onTapGesture { onSelectContainer(container.id) }
        .pointerStyle(.link)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }

    // MARK: - Helpers

    /// Returns just the last path component + tag, e.g. "alpine:latest" from
    /// "ghcr.io/linuxcontainers/alpine:latest"
    private func shortImageName(_ reference: String) -> String {
        // Strip registry+namespace, keep "name:tag"
        let path = reference.split(separator: "/").last.map(String.init) ?? reference
        return path
    }

    // MARK: - Port cell

    @ViewBuilder
    private func portCell(_ ports: [PortMapping]) -> some View {
        if ports.isEmpty {
            Text("—")
                .font(.body)
                .foregroundStyle(LassoColors.antTextDisabled)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(ports.prefix(2), id: \.hostPort) { p in
                    HStack(spacing: 4) {
                        Text(p.proto.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(p.proto.lowercased() == "udp" ? LassoColors.antWarning : LassoColors.antBlue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                (p.proto.lowercased() == "udp" ? LassoColors.antWarning : LassoColors.antBlue).opacity(0.1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        HStack(spacing: 3) {
                            Text(String(p.containerPort))
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(LassoColors.antTextSecondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(LassoColors.antTextDisabled)
                            Text("localhost:\(String(p.hostPort))")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(LassoColors.antBlue)
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
                        .font(.caption2)
                        .foregroundStyle(LassoColors.antTextSecondary)
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: LassoSpacing.md.rawValue) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(LassoColors.antTextDisabled)
            Text("No containers")
                .font(.title3.weight(.medium))
                .foregroundStyle(LassoColors.antTextPrimary)
            Text("Click \"New container\" to get started.")
                .font(.subheadline)
                .foregroundStyle(LassoColors.antTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
