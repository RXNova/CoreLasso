import SwiftUI
import LassoCore
import LassoData

struct NetworkingView: View {

    @Bindable var viewModel: DashboardViewModel
    @Environment(\.md3Scheme) private var scheme

    @State private var showCreateSheet = false
    @State private var newNetworkName = ""
    @State private var hoveredNetID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Spacer()
                Button {
                    Task { await viewModel.pruneNetworks() }
                } label: {
                    Label("Prune Unused", systemImage: "trash.slash")
                }
                .buttonStyle(MD3ButtonStyle(.tonal))
                .help("Remove networks not in use by any container")
                Button {
                    newNetworkName = ""
                    showCreateSheet = true
                } label: {
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
                Text("SUBNET (IPv4)").frame(width: 160, alignment: .leading)
                Text("SUBNET (IPv6)").frame(width: 160, alignment: .leading)
                Text("STATE").frame(width: 80, alignment: .leading)
                Spacer().frame(width: 50)
            }
            .font(MD3Typography.labelSmall)
            .tracking(0.6)
            .foregroundStyle(scheme.onSurfaceVariant)
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .background(scheme.surfaceContainerLow)
            .overlay(alignment: .bottom) { Divider() }

            // Content
            if viewModel.networks.isEmpty {
                Spacer()
                placeholderDetail(icon: "network", title: "No networks",
                                  subtitle: "Create a network to connect containers.", scheme: scheme)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.networks, id: \.id) { net in
                            networkRow(net)
                            Divider().padding(.leading, LassoSpacing.lg.rawValue)
                        }
                    }
                }
                .background(scheme.surface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(scheme.surfaceContainerLowest)
        .sheet(isPresented: $showCreateSheet) { createSheet }
    }

    // MARK: - Network row

    private func networkRow(_ net: CLINetworkEntry) -> some View {
        HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "network")
                    .foregroundStyle(scheme.primary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(net.id)
                        .font(MD3Typography.bodyLarge)
                        .foregroundStyle(scheme.onSurface)
                        .lineLimit(1)
                    Text(net.config?.mode ?? "\u{2014}")
                        .font(.caption.monospaced())
                        .foregroundStyle(scheme.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(net.status?.ipv4Subnet ?? "\u{2014}")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(net.status?.ipv4Subnet != nil ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.opacity(0.5))
                .frame(width: 160, alignment: .leading)
            Text(net.status?.ipv6Subnet ?? "\u{2014}")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(net.status?.ipv6Subnet != nil ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.opacity(0.5))
                .frame(width: 160, alignment: .leading)
            Group {
                if let state = net.state {
                    Text(state)
                        .font(MD3Typography.labelMedium)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(state == "active"
                            ? scheme.successContainer
                            : scheme.surfaceContainerHighest)
                        .foregroundStyle(state == "active" ? scheme.onSuccessContainer : scheme.onSurfaceVariant)
                        .clipShape(Capsule())
                } else {
                    Text("\u{2014}")
                        .font(MD3Typography.bodyMedium)
                        .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
                }
            }
            .frame(width: 80, alignment: .leading)
            Button {
                Task { await viewModel.deleteNetwork(name: net.id) }
            } label: {
                Image(systemName: "trash")
                    .font(MD3Typography.labelMedium)
                    .foregroundStyle(scheme.error)
                    .frame(width: 26, height: 26)
                    .background(scheme.error.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, LassoSpacing.sm.rawValue)
        .background(hoveredNetID == net.id ? scheme.primary.opacity(0.08) : scheme.surface)
        .contentShape(Rectangle())
        .onHover { hoveredNetID = $0 ? net.id : nil }
        .animation(.easeOut(duration: 0.12), value: hoveredNetID == net.id)
        .pointerStyle(.link)
    }

    // MARK: - Create sheet

    private var createSheet: some View {
        VStack(spacing: LassoSpacing.lg.rawValue) {
            Text("Create Network")
                .font(MD3Typography.titleLarge)
                .foregroundStyle(scheme.onSurface)
            TextField("Network name", text: $newNetworkName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { showCreateSheet = false }
                    .buttonStyle(MD3ButtonStyle(.outlined))
                Spacer()
                Button("Create") {
                    let name = newNetworkName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    showCreateSheet = false
                    Task { await viewModel.createNetwork(name: name) }
                }
                .buttonStyle(MD3ButtonStyle(.filled))
                .disabled(newNetworkName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(LassoSpacing.xl.rawValue)
        .frame(width: 360)
    }
}
