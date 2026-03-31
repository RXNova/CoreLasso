import SwiftUI
import LassoCore

/// Detail view for a single container — Ant Design style.
public struct ContainerDetailView: View {

    @Bindable private var viewModel: ContainerDetailViewModel
    @State private var showEditSheet = false
    private let onRecreate: (() -> Void)?

    public init(viewModel: ContainerDetailViewModel, onRecreate: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onRecreate = onRecreate
    }

    private var container: ContainerInfo { viewModel.container }
    private var spec: LassoSpec { container.spec }

    public var body: some View {
        ScrollView {
            VStack(spacing: LassoSpacing.md.rawValue) {
                headerSection
                statusSection
                if viewModel.stats != nil || container.state == .running {
                    statsSection
                }
                resourcesSection
                networkingSection
                storageSection
                if !spec.environment.isEmpty { environmentSection }
                if spec.rosetta || spec.sshForwarding || spec.tty || spec.interactive { optionsSection }
            }
            .padding(LassoSpacing.lg.rawValue)
        }
        .background(LassoColors.antPageBg)
        .task {
            await viewModel.observeState()
        }
        .task {
            await viewModel.startStreaming()
        }
        .sheet(isPresented: $showEditSheet) {
            CreateContainerView(editing: container, engine: viewModel.engine) {
                showEditSheet = false
                onRecreate?()
            }
        }
        .alert(
            "Error",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: { Button("OK") { viewModel.errorMessage = nil } },
            message: { Text(viewModel.errorMessage ?? "") }
        )
    }

    @State private var showExportAlert = false
    @State private var exportTag = ""

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: LassoSpacing.md.rawValue) {
            ZStack {
                RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                    .fill(LassoColors.antBlueBg)
                    .frame(width: 44, height: 44)
                Image(systemName: "server.rack")
                    .font(.title3)
                    .foregroundStyle(LassoColors.antBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.name)
                    .font(.title2.bold())
                    .foregroundStyle(LassoColors.antTextPrimary)
                Text(spec.image)
                    .font(.subheadline)
                    .foregroundStyle(LassoColors.antTextSecondary)
            }
            Spacer()
            StatusBadge(state: container.state)
            Divider().frame(height: 24).padding(.horizontal, 4)
            // ── Action buttons ──────────────────────────────────────────
            if container.state == .stopped || container.state == .created {
                headerButton("play.fill", label: "Start", color: LassoColors.antSuccess) {
                    Task { await viewModel.start() }
                }
            }
            if container.state == .running {
                headerButton("stop.fill", label: "Stop", color: LassoColors.antWarning) {
                    Task { await viewModel.stop() }
                }
                headerButton("xmark.octagon.fill", label: "Kill", color: LassoColors.antError) {
                    Task { await viewModel.kill() }
                }
            }
            headerButton("pencil", label: "Edit", color: LassoColors.antBlue) {
                showEditSheet = true
            }
            if viewModel.canExport {
                headerButton("square.and.arrow.up", label: "Export", color: LassoColors.antTextSecondary) {
                    exportTag = "\(spec.name):exported"
                    showExportAlert = true
                }
            }
            if viewModel.isPerformingAction {
                ProgressView().controlSize(.small).padding(.leading, 4)
            }
        }
        .padding(LassoSpacing.md.rawValue)
        .background(LassoColors.antCardBg)
        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous)
                .stroke(LassoColors.antBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
        .alert("Export Container", isPresented: $showExportAlert) {
            TextField("Image tag", text: $exportTag)
            Button("Export") { Task { await viewModel.export(tag: exportTag.isEmpty ? nil : exportTag) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Export \(spec.name) to a new local image.")
        }
    }

    private func headerButton(_ icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(color.opacity(0.8))
            }
            .frame(width: 42, height: 36)
            .background(color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
            .disabled(viewModel.isPerformingAction)
            .help(label)
            .pointerStyle(.link)
    }

    // MARK: - Status

    private var statusSection: some View {
        sectionCard("Status") {
            infoRow("State") { StatusBadge(state: container.state) }
            infoRow("Created") { Text(container.createdAt.map { formatDate($0) } ?? "—").font(.body).foregroundStyle(LassoColors.antTextPrimary) }
            if let startedAt = container.startedAt {
                infoRow("Started") { Text(formatDate(startedAt)).font(.body).foregroundStyle(LassoColors.antTextPrimary) }
            }
            if let stoppedAt = container.stoppedAt {
                infoRow("Stopped") { Text(formatDate(stoppedAt)).font(.body).foregroundStyle(LassoColors.antTextPrimary) }
            }
            if let pid = container.pid {
                infoRow("PID") { Text("\(pid)").font(.body.monospaced()).foregroundStyle(LassoColors.antTextPrimary) }
            }
            if let errorMsg = container.errorMessage {
                HStack(spacing: LassoSpacing.sm.rawValue) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(LassoColors.antError)
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(LassoColors.antError)
                }
                .padding(.vertical, LassoSpacing.sm.rawValue)
            }
        }
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        sectionCard("Resources") {
            infoRow("CPU Cores") { Text("\(spec.resources.cpuCount)").font(.body).foregroundStyle(LassoColors.antTextPrimary) }
            infoRow("Memory") { Text(formattedMemory(spec.resources.memorySize)).font(.body).foregroundStyle(LassoColors.antTextPrimary) }
        }
    }

    // MARK: - Networking

    private var networkingSection: some View {
        sectionCard("Networking") {
            infoRow("Mode") { Text(spec.networking.mode.rawValue.uppercased()).font(.body).foregroundStyle(LassoColors.antTextPrimary) }
            if let bridge = spec.networking.bridgeInterface {
                infoRow("Bridge Interface") { Text(bridge).font(.body.monospaced()).foregroundStyle(LassoColors.antTextPrimary) }
            }
            if let mac = spec.networking.macAddress {
                infoRow("MAC Address") { Text(mac).font(.body.monospaced()).foregroundStyle(LassoColors.antTextPrimary) }
            }
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        sectionCard("Storage") {
            if spec.storage.isEmpty {
                Text("No storage mounts configured.")
                    .font(.body)
                    .foregroundStyle(LassoColors.antTextSecondary)
                    .padding(.vertical, LassoSpacing.sm.rawValue)
            } else {
                ForEach(Array(spec.storage.enumerated()), id: \.offset) { index, mount in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mount.imagePath)
                                .font(.body.monospaced())
                                .foregroundStyle(LassoColors.antTextPrimary)
                            if let dest = mount.containerPath {
                                Text("→ \(dest)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(LassoColors.antTextSecondary)
                            }
                            HStack(spacing: LassoSpacing.sm.rawValue) {
                                let resolvedSize = mount.size ?? viewModel.volumeSizes[mount.imagePath]
                                if let size = resolvedSize {
                                    Text(formattedStorageSize(size))
                                        .font(.caption)
                                        .foregroundStyle(LassoColors.antTextSecondary)
                                }
                                Text(mount.filesystem.rawValue.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(LassoColors.antTextSecondary)
                                if mount.readOnly {
                                    Text("READ-ONLY")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(LassoColors.antWarningBg)
                                        .foregroundStyle(LassoColors.antWarning)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, LassoSpacing.sm.rawValue)
                    if index < spec.storage.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        sectionCard("Resource Usage") {
            let s = viewModel.stats
            infoRow("CPU Time") {
                if let usec = s?.cpuUsageUsec {
                    Text(formatMicroseconds(usec))
                        .font(.body.monospaced()).foregroundStyle(LassoColors.antTextPrimary)
                } else { statPlaceholder() }
            }
            infoRow("Memory") {
                if let used = s?.memoryUsageBytes, let limit = s?.memoryLimitBytes {
                    let pct = limit > 0 ? Double(used) / Double(limit) : 0
                    HStack(spacing: 8) {
                        Text("\(formatBytes(used)) / \(formatBytes(limit))")
                            .font(.body.monospaced()).foregroundStyle(LassoColors.antTextPrimary)
                        ProgressView(value: pct).frame(width: 80)
                    }
                } else { statPlaceholder() }
            }
            infoRow("Network I/O") {
                if let rx = s?.networkRxBytes, let tx = s?.networkTxBytes {
                    Text("↓ \(formatBytes(rx))  ↑ \(formatBytes(tx))")
                        .font(.body.monospaced()).foregroundStyle(LassoColors.antTextPrimary)
                } else { statPlaceholder() }
            }
            infoRow("Block I/O") {
                if let r = s?.blockReadBytes, let w = s?.blockWriteBytes {
                    Text("R \(formatBytes(r))  W \(formatBytes(w))")
                        .font(.body.monospaced()).foregroundStyle(LassoColors.antTextPrimary)
                } else { statPlaceholder() }
            }
            infoRow("Processes") {
                if let procs = s?.numProcesses {
                    Text("\(procs)").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                } else { statPlaceholder() }
            }
        }
    }

    @ViewBuilder
    private func statPlaceholder() -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text("—").font(.body.monospaced()).foregroundStyle(LassoColors.antTextDisabled)
        }
    }

    // MARK: - Environment

    private var environmentSection: some View {
        sectionCard("Environment Variables") {
            ForEach(spec.environment, id: \.self) { env in
                Text(env)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(LassoColors.antTextPrimary)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        sectionCard("Options") {
            if spec.rosetta {
                infoRow("Rosetta") {
                    Text("Enabled").font(.body).foregroundStyle(LassoColors.antSuccess)
                }
            }
            if spec.sshForwarding {
                infoRow("SSH Forwarding") {
                    Text("Enabled").font(.body).foregroundStyle(LassoColors.antSuccess)
                }
            }
            if spec.tty {
                infoRow("TTY") {
                    Text("Allocated").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                }
            }
            if spec.interactive {
                infoRow("Interactive") {
                    Text("stdin open").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                }
            }
        }
    }

    // MARK: - Components

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
            }
            .padding(.horizontal, LassoSpacing.md.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .background(LassoColors.arcTableHeader)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, LassoSpacing.md.rawValue)
        }
        .background(LassoColors.antCardBg)
        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous)
                .stroke(LassoColors.antBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
    }

    private func infoRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.body)
                .foregroundStyle(LassoColors.antTextSecondary)
                .frame(width: 130, alignment: .leading)
            value()
            Spacer()
        }
        .padding(.vertical, LassoSpacing.sm.rawValue)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    private func formattedMemory(_ bytes: UInt64) -> String {
        let gib = Double(bytes) / (1024 * 1024 * 1024)
        if gib >= 1.0 { return String(format: "%.1f GiB", gib) }
        return String(format: "%.0f MiB", Double(bytes) / (1024 * 1024))
    }

    private func formattedStorageSize(_ bytes: UInt64) -> String {
        String(format: "%.1f GiB", Double(bytes) / (1024 * 1024 * 1024))
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb >= 1    { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }

    private func formatMicroseconds(_ usec: UInt64) -> String {
        let ms = Double(usec) / 1000
        if ms >= 1000 { return String(format: "%.2f s", ms / 1000) }
        return String(format: "%.1f ms", ms)
    }
}
