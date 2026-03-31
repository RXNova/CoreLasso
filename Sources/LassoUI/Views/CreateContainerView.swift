import SwiftUI
import AppKit
import LassoCore

/// Sheet form for creating a new container — Ant Design style.
public struct CreateContainerView: View {

    @Bindable private var viewModel: CreateContainerViewModel
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
                    .font(.title3.bold())
                    .foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(LassoColors.antTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(LassoSpacing.lg.rawValue)
            .background(Color.white)
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
            .background(LassoColors.antPageBg)

            // Footer
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Spacer()
                Button { onDismiss() } label: { Text("Cancel") }
                    .buttonStyle(GlassButtonStyle(.secondary))
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
                .buttonStyle(GlassButtonStyle(.primary))
                .disabled(!viewModel.isValid || viewModel.isCreating)
            }
            .padding(LassoSpacing.md.rawValue)
            .background(Color.white)
            .overlay(alignment: .top) { Divider() }
        }
        .frame(minWidth: 520, minHeight: 600)
        .task { await viewModel.loadAvailableImages() }
    }

    // MARK: - General

    private var generalSection: some View {
        formCard("General") {
            formField("Name") {
                TextField("my-container", text: $viewModel.name)
                    .textFieldStyle(.plain)
                    .padding(LassoSpacing.sm.rawValue)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                    .overlay(
                        RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                            .stroke(LassoColors.antBorder, lineWidth: 0.5)
                    )
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
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LassoColors.antTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LassoSpacing.sm.rawValue)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
            .overlay(
                RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                    .stroke(showImageSuggestions ? LassoColors.antBlue : LassoColors.antBorder, lineWidth: showImageSuggestions ? 1 : 0.5)
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
                                    .font(.caption)
                                    .foregroundStyle(LassoColors.antBlue)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(img.reference)
                                        .font(.body)
                                        .foregroundStyle(LassoColors.antTextPrimary)
                                        .lineLimit(1)
                                    if let size = img.size {
                                        Text(size)
                                            .font(.caption)
                                            .foregroundStyle(LassoColors.antTextSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, LassoSpacing.sm.rawValue)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color.white)
                        .onHover { h in _ = h }
                        if img.id != imageSuggestions.prefix(8).last?.id {
                            Divider().padding(.leading, 28)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                .overlay(
                    RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                        .stroke(LassoColors.antBorder, lineWidth: 0.5)
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
                Text("CPU Cores").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
                Stepper("\(viewModel.cpuCount)", value: $viewModel.cpuCount, in: 1...ProcessInfo.processInfo.processorCount)
            }
            Divider()
            HStack {
                Text("Memory (MiB)").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
                HStack(spacing: 4) {
                    TextField("", value: $viewModel.memoryMiB, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: viewModel.memoryMiB) {
                            if viewModel.memoryMiB < 128 { viewModel.memoryMiB = 128 }
                        }
                    Text("MiB").font(.body).foregroundStyle(LassoColors.antTextSecondary)
                }
            }
        }
    }

    // MARK: - Networking

    private var networkingSection: some View {
        formCard("Networking") {
            HStack {
                Text("Mode").font(.body).foregroundStyle(LassoColors.antTextPrimary)
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
                    TextField("en0", text: $viewModel.bridgeInterface)
                        .textFieldStyle(.plain)
                        .padding(LassoSpacing.sm.rawValue)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                        .overlay(
                            RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                                .stroke(LassoColors.antBorder, lineWidth: 0.5)
                        )
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Port Mappings")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LassoColors.antTextSecondary)
                Text("Format: hostPort:containerPort  or  hostPort:containerPort/tcp")
                    .font(.caption2)
                    .foregroundStyle(LassoColors.antTextDisabled)
                ForEach(viewModel.portMappingEntries.indices, id: \.self) { i in
                    HStack(spacing: LassoSpacing.sm.rawValue) {
                        TextField("8080:80", text: $viewModel.portMappingEntries[i])
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(LassoSpacing.sm.rawValue)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                            .overlay(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                                .stroke(LassoColors.antBorder, lineWidth: 0.5))
                        Button { viewModel.portMappingEntries.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(LassoColors.antError)
                        }.buttonStyle(.plain)
                    }
                }
                Button { viewModel.portMappingEntries.append("") } label: {
                    Label("Add Port", systemImage: "plus")
                        .font(.subheadline).foregroundStyle(LassoColors.antBlue)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        formCard("Volumes & Mounts") {
            if viewModel.volumeMountEntries.isEmpty {
                Text("No mounts configured.")
                    .font(.caption)
                    .foregroundStyle(LassoColors.antTextSecondary)
                    .padding(.vertical, LassoSpacing.xs.rawValue)
            } else {
                VStack(spacing: 0) {
                    // Column headers
                    HStack(spacing: LassoSpacing.sm.rawValue) {
                        Text("SOURCE")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("CONTAINER PATH")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("RO")
                            .frame(width: 28, alignment: .center)
                        Spacer().frame(width: 28)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(LassoColors.antTextDisabled)
                    .padding(.bottom, LassoSpacing.xs.rawValue)

                    ForEach($viewModel.volumeMountEntries) { $entry in
                        HStack(spacing: LassoSpacing.sm.rawValue) {
                            HStack(spacing: 4) {
                                TextField("pgdata  or  /host/path", text: $entry.source)
                                    .textFieldStyle(.plain)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(LassoSpacing.sm.rawValue)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                                    .overlay(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                                        .stroke(LassoColors.antBorder, lineWidth: 0.5))
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
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(LassoColors.antBlue)
                                        .frame(width: 26, height: 26)
                                        .background(LassoColors.antBlue.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                                .buttonStyle(.plain)
                                .help("Pick folder…")
                            }
                            .frame(maxWidth: .infinity)

                            TextField("/var/lib/data", text: $entry.target)
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .padding(LassoSpacing.sm.rawValue)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                                .overlay(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                                    .stroke(LassoColors.antBorder, lineWidth: 0.5))
                                .frame(maxWidth: .infinity)

                            Toggle("", isOn: $entry.readOnly)
                                .labelsHidden()
                                .frame(width: 28)
                                .help("Read-only mount")

                            Button {
                                viewModel.volumeMountEntries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(LassoColors.antError)
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LassoColors.antBlue)
            }
            .buttonStyle(.plain)

            Text("Named volume (e.g. pgdata) or absolute host path (e.g. /Users/me/data). Named volumes must be created first in the Volumes tab.")
                .font(.caption)
                .foregroundStyle(LassoColors.antTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Environment Variables

    private var environmentSection: some View {
        formCard("Environment Variables") {
            ForEach(viewModel.environmentEntries.indices, id: \.self) { i in
                HStack(spacing: LassoSpacing.xs.rawValue) {
                    TextField("KEY=value", text: $viewModel.environmentEntries[i])
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .padding(LassoSpacing.sm.rawValue)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                        .overlay(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                            .stroke(LassoColors.antBorder, lineWidth: 0.5))
                    Button { viewModel.environmentEntries.remove(at: i) } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(LassoColors.antError)
                    }.buttonStyle(.plain)
                }
            }
            Button {
                viewModel.environmentEntries.append("")
            } label: {
                Label("Add Variable", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(LassoColors.antBlue)
            }.buttonStyle(.plain)
        }
    }

    // MARK: - DNS

    private var dnsSection: some View {
        formCard("DNS") {
            if !viewModel.dnsServers.isEmpty {
                Text("Nameservers")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LassoColors.antTextSecondary)
                ForEach(viewModel.dnsServers.indices, id: \.self) { i in
                    HStack(spacing: LassoSpacing.xs.rawValue) {
                        TextField("8.8.8.8", text: $viewModel.dnsServers[i])
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(LassoSpacing.sm.rawValue)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                            .overlay(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                                .stroke(LassoColors.antBorder, lineWidth: 0.5))
                        Button { viewModel.dnsServers.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(LassoColors.antError)
                        }.buttonStyle(.plain)
                    }
                }
            }
            if !viewModel.dnsSearchDomains.isEmpty {
                Divider()
                Text("Search Domains")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LassoColors.antTextSecondary)
                ForEach(viewModel.dnsSearchDomains.indices, id: \.self) { i in
                    HStack(spacing: LassoSpacing.xs.rawValue) {
                        TextField("example.com", text: $viewModel.dnsSearchDomains[i])
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(LassoSpacing.sm.rawValue)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
                            .overlay(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                                .stroke(LassoColors.antBorder, lineWidth: 0.5))
                        Button { viewModel.dnsSearchDomains.remove(at: i) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(LassoColors.antError)
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Button { viewModel.dnsServers.append("") } label: {
                    Label("Add Nameserver", systemImage: "plus")
                        .font(.subheadline).foregroundStyle(LassoColors.antBlue)
                }.buttonStyle(.plain)
                Spacer()
                Button { viewModel.dnsSearchDomains.append("") } label: {
                    Label("Add Search Domain", systemImage: "plus")
                        .font(.subheadline).foregroundStyle(LassoColors.antBlue)
                }.buttonStyle(.plain)
            }
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        formCard("Options") {
            Toggle(isOn: $viewModel.rosetta) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rosetta").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                    Text("Enable x86/x64 translation (macOS 13+)")
                        .font(.caption).foregroundStyle(LassoColors.antTextSecondary)
                }
            }
            Divider()
            Toggle(isOn: $viewModel.sshForwarding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SSH Agent Forwarding").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                    Text("Forward host SSH agent socket into container")
                        .font(.caption).foregroundStyle(LassoColors.antTextSecondary)
                }
            }
            Divider()
            Toggle(isOn: $viewModel.tty) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TTY").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                    Text("Allocate a pseudo-TTY for the container process")
                        .font(.caption).foregroundStyle(LassoColors.antTextSecondary)
                }
            }
            Divider()
            Toggle(isOn: $viewModel.interactive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Interactive (stdin)").font(.body).foregroundStyle(LassoColors.antTextPrimary)
                    Text("Keep stdin open even when not attached")
                        .font(.caption).foregroundStyle(LassoColors.antTextSecondary)
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
                    .foregroundStyle(LassoColors.antError)
                Text(error)
                    .font(.body)
                    .foregroundStyle(LassoColors.antError)
            }
            .padding(LassoSpacing.md.rawValue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LassoColors.antErrorBg)
            .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue))
            .overlay(
                RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue)
                    .stroke(LassoColors.antError.opacity(0.3), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Helpers

    private func formCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
            }
            .padding(.horizontal, LassoSpacing.md.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .background(Color(red: 0.980, green: 0.980, blue: 0.980))

            Divider()

            VStack(alignment: .leading, spacing: LassoSpacing.sm.rawValue) {
                content()
            }
            .padding(LassoSpacing.md.rawValue)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LassoRadius.sm.rawValue, style: .continuous)
                .stroke(LassoColors.antBorder, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(LassoColors.antTextSecondary)
            content()
        }
    }
}
