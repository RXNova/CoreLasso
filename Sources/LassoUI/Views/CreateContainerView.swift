import SwiftUI
import AppKit
import LassoCore

/// Sheet form for creating a new container — Material Design 3 style.
public struct CreateContainerView: View {

    @Bindable private var viewModel: CreateContainerViewModel
    @Environment(\.md3Scheme) private var scheme
    private let onDismiss: () -> Void

    @State private var showImageSuggestions = false

    public init(engine: any LassoContainerEngine, onDismiss: @escaping () -> Void) {
        self.viewModel = CreateContainerViewModel(engine: engine)
        self.onDismiss = onDismiss
    }

    /// Edit mode — pre-fills the form from the existing container.
    public init(editing container: ContainerInfo, engine: any LassoContainerEngine, onDismiss: @escaping () -> Void) {
        self.viewModel = CreateContainerViewModel(editing: container, engine: engine)
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(viewModel.isEditMode ? "Edit Container" : "Create Container")
                    .font(MD3Typography.titleLarge)
                    .foregroundStyle(scheme.onSurface)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(MD3Typography.bodyLarge)
                        .foregroundStyle(scheme.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
            .padding(LassoSpacing.lg.rawValue)
            .background(scheme.surface)
            .overlay(alignment: .bottom) { Divider() }

            // Form
            ScrollView {
                VStack(spacing: LassoSpacing.md.rawValue) {
                    generalSection
                    resourcesSection
                    networkingSection
                    storageSection
                    environmentSection
                    dnsSection
                    optionsSection
                    errorSection
                }
                .padding(LassoSpacing.lg.rawValue)
            }
            .background(scheme.surfaceContainerLowest)

            // Footer
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Spacer()
                Button { onDismiss() } label: { Text("Cancel") }
                    .buttonStyle(MD3ButtonStyle(.outlined))
                Button {
                    Task {
                        if await viewModel.applyChanges() != nil {
                            onDismiss()
                        }
                    }
                } label: {
                    if viewModel.isCreating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(viewModel.isEditMode ? "Save Changes" : "Create")
                    }
                }
                .buttonStyle(MD3ButtonStyle(.filled))
                .disabled(!viewModel.isValid || viewModel.isCreating)
            }
            .padding(LassoSpacing.md.rawValue)
            .background(scheme.surface)
            .overlay(alignment: .top) { Divider() }
        }
        .frame(minWidth: 520, minHeight: 600)
        .task { await viewModel.loadAvailableImages() }
    }

    // MARK: - General

    private var generalSection: some View {
        formCard("General") {
            formField("Name") {
                formTextField("my-container", text: $viewModel.name)
            }
            formField("Image") {
                imageComboBox
            }
        }
    }

    // MARK: - Image combobox

    private var imageSuggestions: [ImageInfo] {
        let q = viewModel.image.lowercased()
        if q.isEmpty { return viewModel.availableImages }
        return viewModel.availableImages.filter { $0.reference.lowercased().contains(q) }
    }

    private var imageComboBox: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                TextField("postgres:16-alpine", text: $viewModel.image)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.image) {
                        showImageSuggestions = !viewModel.availableImages.isEmpty
                    }
                if !viewModel.availableImages.isEmpty {
                    Button {
                        showImageSuggestions.toggle()
                    } label: {
                        Image(systemName: showImageSuggestions ? "chevron.up" : "chevron.down")
                            .font(MD3Typography.labelMedium)
                            .foregroundStyle(scheme.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LassoSpacing.sm.rawValue)
            .background(scheme.surfaceContainerHighest)
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous)
                    .stroke(showImageSuggestions ? scheme.primary : scheme.outline, lineWidth: showImageSuggestions ? 1 : 0.5)
            )

            if showImageSuggestions && !imageSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(imageSuggestions.prefix(8)) { img in
                        Button {
                            viewModel.image = img.reference
                            showImageSuggestions = false
                        } label: {
                            HStack {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(MD3Typography.bodySmall)
                                    .foregroundStyle(scheme.primary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(img.reference)
                                        .font(MD3Typography.bodyMedium)
                                        .foregroundStyle(scheme.onSurface)
                                        .lineLimit(1)
                                    if let size = img.size {
                                        Text(size)
                                            .font(MD3Typography.bodySmall)
                                            .foregroundStyle(scheme.onSurfaceVariant)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, LassoSpacing.sm.rawValue)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if img.id != imageSuggestions.prefix(8).last?.id {
                            Divider().padding(.leading, 28)
                        }
                    }
                }
                .background(scheme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous)
                        .stroke(scheme.outlineVariant, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .zIndex(100)
            }
        }
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        formCard("Resources") {
            HStack {
                Text("CPU Cores").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                Spacer()
                Stepper("\(viewModel.cpuCount)", value: $viewModel.cpuCount, in: 1...ProcessInfo.processInfo.processorCount)
            }
            Divider()
            HStack {
                Text("Memory (MiB)").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                Spacer()
                HStack(spacing: 4) {
                    TextField("", value: $viewModel.memoryMiB, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.memoryMiB) {
                            if viewModel.memoryMiB < 128 { viewModel.memoryMiB = 128 }
                        }
                    Text("MiB").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurfaceVariant)
                }
            }
        }
    }

    // MARK: - Networking

    private var networkingSection: some View {
        formCard("Networking") {
            HStack {
                Text("Mode").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                Spacer()
                Picker("", selection: $viewModel.networkMode) {
                    Text("NAT").tag(NetworkSpec.NetworkMode.nat)
                    Text("Bridged").tag(NetworkSpec.NetworkMode.bridged)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            if viewModel.networkMode == .bridged {
                Divider()
                formField("Bridge Interface") {
                    formTextField("en0", text: $viewModel.bridgeInterface)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Port Mappings")
                    .font(MD3Typography.labelMedium)
                    .foregroundStyle(scheme.onSurfaceVariant)
                Text("Format: hostPort:containerPort  or  hostPort:containerPort/tcp")
                    .font(MD3Typography.labelSmall)
                    .foregroundStyle(scheme.onSurfaceVariant.opacity(0.6))
                ForEach(viewModel.portMappingEntries.indices, id: \.self) { i in
                    HStack(spacing: LassoSpacing.sm.rawValue) {
                        formTextField("8080:80", text: $viewModel.portMappingEntries[i], monospaced: true)
                        Button { viewModel.portMappingEntries.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(scheme.error)
                        }.buttonStyle(.plain)
                    }
                }
                Button { viewModel.portMappingEntries.append("") } label: {
                    Label("Add Port", systemImage: "plus")
                        .font(MD3Typography.labelLarge).foregroundStyle(scheme.primary)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        formCard("Volumes & Mounts") {
            if viewModel.volumeMountEntries.isEmpty {
                Text("No mounts configured.")
                    .font(MD3Typography.bodySmall)
                    .foregroundStyle(scheme.onSurfaceVariant)
                    .padding(.vertical, LassoSpacing.xs.rawValue)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: LassoSpacing.sm.rawValue) {
                        Text("SOURCE")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("CONTAINER PATH")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("RO")
                            .frame(width: 28, alignment: .center)
                        Spacer().frame(width: 28)
                    }
                    .font(MD3Typography.labelSmall)
                    .foregroundStyle(scheme.onSurfaceVariant.opacity(0.6))
                    .padding(.bottom, LassoSpacing.xs.rawValue)

                    ForEach($viewModel.volumeMountEntries) { $entry in
                        HStack(spacing: LassoSpacing.sm.rawValue) {
                            HStack(spacing: 4) {
                                formTextField("pgdata  or  /host/path", text: $entry.source, monospaced: true)
                                Button {
                                    let panel = NSOpenPanel()
                                    panel.canChooseDirectories = true
                                    panel.canChooseFiles = false
                                    panel.allowsMultipleSelection = false
                                    panel.prompt = "Select"
                                    if panel.runModal() == .OK, let url = panel.url {
                                        entry.source = url.path
                                    }
                                } label: {
                                    Image(systemName: "folder")
                                        .font(MD3Typography.labelMedium)
                                        .foregroundStyle(scheme.primary)
                                        .frame(width: 26, height: 26)
                                        .background(scheme.primaryContainer)
                                        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                                }
                                .buttonStyle(.plain)
                                .help("Pick folder\u{2026}")
                            }
                            .frame(maxWidth: .infinity)

                            formTextField("/var/lib/data", text: $entry.target, monospaced: true)
                                .frame(maxWidth: .infinity)

                            Toggle("", isOn: $entry.readOnly)
                                .labelsHidden()
                                .frame(width: 28)
                                .help("Read-only mount")

                            Button {
                                viewModel.volumeMountEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(scheme.error)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 28)
                        }
                        .padding(.vertical, 4)

                        if entry.id != viewModel.volumeMountEntries.last?.id {
                            Divider()
                        }
                    }
                }
            }

            Divider()
            Button {
                viewModel.volumeMountEntries.append(VolumeMountEntry())
            } label: {
                Label("Add Mount", systemImage: "plus.circle")
                    .font(MD3Typography.labelLarge)
                    .foregroundStyle(scheme.primary)
            }
            .buttonStyle(.plain)

            Text("Named volume (e.g. pgdata) or absolute host path (e.g. /Users/me/data). Named volumes must be created first in the Volumes tab.")
                .font(MD3Typography.bodySmall)
                .foregroundStyle(scheme.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Environment Variables

    private var environmentSection: some View {
        formCard("Environment Variables") {
            ForEach(viewModel.environmentEntries.indices, id: \.self) { i in
                HStack(spacing: LassoSpacing.xs.rawValue) {
                    formTextField("KEY=value", text: $viewModel.environmentEntries[i], monospaced: true)
                    Button { viewModel.environmentEntries.remove(at: i) } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(scheme.error)
                    }.buttonStyle(.plain)
                }
            }
            Button {
                viewModel.environmentEntries.append("")
            } label: {
                Label("Add Variable", systemImage: "plus")
                    .font(MD3Typography.labelLarge)
                    .foregroundStyle(scheme.primary)
            }.buttonStyle(.plain)
        }
    }

    // MARK: - DNS

    private var dnsSection: some View {
        formCard("DNS") {
            if !viewModel.dnsServers.isEmpty {
                Text("Nameservers")
                    .font(MD3Typography.labelMedium)
                    .foregroundStyle(scheme.onSurfaceVariant)
                ForEach(viewModel.dnsServers.indices, id: \.self) { i in
                    HStack(spacing: LassoSpacing.xs.rawValue) {
                        formTextField("8.8.8.8", text: $viewModel.dnsServers[i], monospaced: true)
                        Button { viewModel.dnsServers.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(scheme.error)
                        }.buttonStyle(.plain)
                    }
                }
            }
            if !viewModel.dnsSearchDomains.isEmpty {
                Divider()
                Text("Search Domains")
                    .font(MD3Typography.labelMedium)
                    .foregroundStyle(scheme.onSurfaceVariant)
                ForEach(viewModel.dnsSearchDomains.indices, id: \.self) { i in
                    HStack(spacing: LassoSpacing.xs.rawValue) {
                        formTextField("example.com", text: $viewModel.dnsSearchDomains[i], monospaced: true)
                        Button { viewModel.dnsSearchDomains.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(scheme.error)
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Button { viewModel.dnsServers.append("") } label: {
                    Label("Add Nameserver", systemImage: "plus")
                        .font(MD3Typography.labelLarge).foregroundStyle(scheme.primary)
                }.buttonStyle(.plain)
                Spacer()
                Button { viewModel.dnsSearchDomains.append("") } label: {
                    Label("Add Search Domain", systemImage: "plus")
                        .font(MD3Typography.labelLarge).foregroundStyle(scheme.primary)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        formCard("Options") {
            Toggle(isOn: $viewModel.rosetta) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rosetta").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                    Text("Enable x86/x64 translation (macOS 13+)")
                        .font(MD3Typography.bodySmall).foregroundStyle(scheme.onSurfaceVariant)
                }
            }
            Divider()
            Toggle(isOn: $viewModel.sshForwarding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SSH Agent Forwarding").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                    Text("Forward host SSH agent socket into container")
                        .font(MD3Typography.bodySmall).foregroundStyle(scheme.onSurfaceVariant)
                }
            }
            Divider()
            Toggle(isOn: $viewModel.tty) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TTY").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                    Text("Allocate a pseudo-TTY for the container process")
                        .font(MD3Typography.bodySmall).foregroundStyle(scheme.onSurfaceVariant)
                }
            }
            Divider()
            Toggle(isOn: $viewModel.interactive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interactive (stdin)").font(MD3Typography.bodyMedium).foregroundStyle(scheme.onSurface)
                    Text("Keep stdin open even when not attached")
                        .font(MD3Typography.bodySmall).foregroundStyle(scheme.onSurfaceVariant)
                }
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(scheme.error)
                Text(error)
                    .font(MD3Typography.bodyMedium)
                    .foregroundStyle(scheme.error)
            }
            .padding(LassoSpacing.md.rawValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(scheme.errorContainer)
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.lg.rawValue, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LassoRadius.lg.rawValue, style: .continuous)
                    .stroke(scheme.error.opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Helpers

    private func formCard<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        MD3SectionCard(title, variant: .outlined) {
            VStack(alignment: .leading, spacing: LassoSpacing.sm.rawValue) {
                content()
            }
            .padding(.vertical, LassoSpacing.sm.rawValue)
        }
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
            Text(label)
                .font(MD3Typography.labelMedium)
                .foregroundStyle(scheme.onSurfaceVariant)
            content()
        }
    }

    private func formTextField(_ placeholder: String, text: Binding<String>, monospaced: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(monospaced ? .system(.body, design: .monospaced) : MD3Typography.bodyMedium)
            .padding(LassoSpacing.sm.rawValue)
            .background(scheme.surfaceContainerHighest)
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous)
                    .stroke(scheme.outline, lineWidth: 0.5)
            )
    }
}
