import SwiftUI
import LassoCore

/// Detail view for a single container — Material Design 3 style.
public struct ContainerDetailView: View {

    @Bindable private var viewModel: ContainerDetailViewModel
    @Environment(\.md3Scheme) private var scheme
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
            VStack(spacing: LassoSpacing.lg.rawValue) {
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
        .background(scheme.surfaceContainerLowest)
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
                RoundedRectangle(cornerRadius: LassoRadius.md.rawValue, style: .continuous)
                    .fill(scheme.primaryContainer)
                    .frame(width: 44, height: 44)
                Image(systemName: "server.rack")
                    .font(.title3)
                    .foregroundStyle(scheme.onPrimaryContainer)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(spec.name)
                    .font(MD3Typography.headlineSmall)
                    .foregroundStyle(scheme.onSurface)
                Text(spec.image)
                    .font(MD3Typography.bodyMedium)
                    .foregroundStyle(scheme.onSurfaceVariant)
            }
            Spacer()
            StatusBadge(state: container.state)
            Divider().frame(height: 24).padding(.horizontal, 4)
            // Action buttons
            if container.state == .stopped || container.state == .created {
                headerButton("play.fill", label: "Start", color: scheme.success) {
                    Task { await viewModel.start() }
                }
            }
            if container.state == .running {
                headerButton("stop.fill", label: "Stop", color: scheme.warning) {
                    Task { await viewModel.stop() }
                }
                headerButton("xmark.octagon.fill", label: "Kill", color: scheme.error) {
                    Task { await viewModel.kill() }
                }
            }
            headerButton("pencil", label: "Edit", color: scheme.primary) {
                showEditSheet = true
            }
            if viewModel.canExport {
                headerButton("square.and.arrow.up", label: "Export", color: scheme.onSurfaceVariant) {
                    exportTag = "\(spec.name):exported"
                    showExportAlert = true
                }
            }
            if viewModel.isPerformingAction {
                ProgressView().controlSize(.small).padding(.leading, 4)
            }
        }
        .padding(LassoSpacing.md.rawValue)
        .md3Card(.elevated)
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
                    .font(MD3Typography.labelSmall)
                    .foregroundStyle(color.opacity(0.8))
            }
            .frame(width: 42, height: 36)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPerformingAction)
        .help(label)
        .pointerStyle(.link)
    }

    // MARK: - Status

    private var statusSection: some View {
        MD3SectionCard("Status") {
            infoRow("State") { StatusBadge(state: container.state) }
            infoRow("Created") { Text(container.createdAt.map { formatDate($0) } ?? "\u{2014}").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface) }
            if let startedAt = container.startedAt {
                infoRow("Started") { Text(formatDate(startedAt)).font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface) }
            }
            if let stoppedAt = container.stoppedAt {
                infoRow("Stopped") { Text(formatDate(stoppedAt)).font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface) }
            }
            if let pid = container.pid {
                infoRow("PID") { Text("\(pid)").font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurface) }
            }
            if let errorMsg = container.errorMessage {
                HStack(spacing: LassoSpacing.sm.rawValue) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(scheme.error)
                    Text(errorMsg)
                        .font(MD3Typography.bodySmall)
                        .foregroundStyle(scheme.error)
                }
                .padding(.vertical, LassoSpacing.sm.rawValue)
            }
        }
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        MD3SectionCard("Resources") {
            infoRow("CPU Cores") { Text("\(spec.resources.cpuCount)").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface) }
            infoRow("Memory") { Text(formattedMemory(spec.resources.memorySize)).font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface) }
        }
    }

    // MARK: - Networking

    private var networkingSection: some View {
        MD3SectionCard("Networking") {
            infoRow("Mode") { Text(spec.networking.mode.rawValue.uppercased()).font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface) }
            if let bridge = spec.networking.bridgeInterface {
                infoRow("Bridge Interface") { Text(bridge).font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurface) }
            }
            if let mac = spec.networking.macAddress {
                infoRow("MAC Address") { Text(mac).font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurface) }
            }
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        MD3SectionCard("Storage") {
            if spec.storage.isEmpty {
                Text("No storage mounts configured.")
                    .font(MD3Typography.bodyMedium)
                    .foregroundStyle(scheme.onSurfaceVariant)
                    .padding(.vertical, LassoSpacing.sm.rawValue)
            } else {
                ForEach(Array(spec.storage.enumerated()), id: \.offset) { index, mount in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mount.imagePath)
                                .font(MD3Typography.bodyMedium.monospaced())
                                .foregroundStyle(scheme.onSurface)
                            if let dest = mount.containerPath {
                                Text("\u{2192} \(dest)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(scheme.onSurfaceVariant)
                            }
                            HStack(spacing: LassoSpacing.sm.rawValue) {
                                let resolvedSize = mount.size ?? viewModel.volumeSizes[mount.imagePath]
                                if let size = resolvedSize {
                                    Text(formattedStorageSize(size))
                                        .font(MD3Typography.bodySmall)
                                        .foregroundStyle(scheme.onSurfaceVariant)
                                }
                                Text(mount.filesystem.rawValue.uppercased())
                                    .font(MD3Typography.bodySmall)
                                    .foregroundStyle(scheme.onSurfaceVariant)
                                if mount.readOnly {
                                    Text("READ-ONLY")
                                        .font(MD3Typography.labelSmall)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(scheme.warningContainer)
                                        .foregroundStyle(scheme.onWarningContainer)
                                        .clipShape(Capsule())
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
        MD3SectionCard("Resource Usage") {
            let s = viewModel.stats
            infoRow("CPU Time") {
                if let usec = s?.cpuUsageUsec {
                    Text(formatMicroseconds(usec))
                        .font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurface)
                } else { statPlaceholder() }
            }
            infoRow("Memory") {
                if let used = s?.memoryUsageBytes, let limit = s?.memoryLimitBytes {
                    let pct = limit > 0 ? Double(used) / Double(limit) : 0
                    HStack(spacing: 8) {
                        Text("\(formatBytes(used)) / \(formatBytes(limit))")
                            .font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurface)
                        ProgressView(value: pct).frame(width: 80)
                    }
                } else { statPlaceholder() }
            }
            infoRow("Network I/O") {
                if let rx = s?.networkRxBytes, let tx = s?.networkTxBytes {
                    Text("\u{2193} \(formatBytes(rx))  \u{2191} \(formatBytes(tx))")
                        .font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurface)
                } else { statPlaceholder() }
            }
            infoRow("Block I/O") {
                if let r = s?.blockReadBytes, let w = s?.blockWriteBytes {
                    Text("R \(formatBytes(r))  W \(formatBytes(w))")
                        .font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurface)
                } else { statPlaceholder() }
            }
            infoRow("Processes") {
                if let procs = s?.numProcesses {
                    Text("\(procs)").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                } else { statPlaceholder() }
            }
        }
    }

    @ViewBuilder
    private func statPlaceholder() -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini)
            Text("\u{2014}").font(MD3Typography.bodyMedium.monospaced()).foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
        }
    }

    // MARK: - Environment

    private var environmentSection: some View {
        MD3SectionCard("Environment Variables") {
            ForEach(spec.environment, id: \.self) { env in
                Text(env)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(scheme.onSurface)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        MD3SectionCard("Options") {
            if spec.rosetta {
                infoRow("Rosetta") {
                    Text("Enabled").font(MD3Typography.bodyMedium).foregroundStyle(scheme.success)
                }
            }
            if spec.sshForwarding {
                infoRow("SSH Forwarding") {
                    Text("Enabled").font(MD3Typography.bodyMedium).foregroundStyle(scheme.success)
                }
            }
            if spec.tty {
                infoRow("TTY") {
                    Text("Allocated").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                }
            }
            if spec.interactive {
                infoRow("Interactive") {
                    Text("stdin open").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                }
            }
        }
    }

    // MARK: - Components

    private func infoRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(MD3Typography.bodyMedium)
                .foregroundStyle(scheme.onSurfaceVariant)
                .frame(width: 130, alignment: .leading)
            value()
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(scheme.outlineVariant.opacity(0.2))
                .frame(height: 0.5)
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
