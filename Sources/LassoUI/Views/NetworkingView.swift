import SwiftUI
import LassoCore
import LassoData

struct NetworkingView: View {

    @Bindable var viewModel: DashboardViewModel

    @State private var showCreateSheet = false
    @State private var newNetworkName = ""
    @State private var hoveredNetID: String?

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────────────
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Text("Networks")
                    .font(.title2.bold())
                    .foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
                Button {
                    Task { await viewModel.pruneNetworks() }
                } label: {
                    Label("Prune Unused", systemImage: "trash.slash")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(GlassButtonStyle(.secondary))
                .help("Remove networks not in use by any container")
                Button {
                    newNetworkName = ""
                    showCreateSheet = true
                } label: {
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
                Text("SUBNET (IPv4)").frame(width: 160, alignment: .leading)
                Text("SUBNET (IPv6)").frame(width: 160, alignment: .leading)
                Text("STATE").frame(width: 80, alignment: .leading)
                Spacer().frame(width: 50)
            }
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(LassoColors.antTextSecondary)
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .background(LassoColors.arcTableHeader)
            .overlay(alignment: .bottom) { Divider() }

            // ── Content ──────────────────────────────────────────────────
            if viewModel.networks.isEmpty {
                Spacer()
                placeholderDetail(icon: "network", title: "No networks",
                                  subtitle: "Create a network to connect containers.")
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
                .background(LassoColors.antCardBg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(LassoColors.antPageBg)
        .sheet(isPresented: $showCreateSheet) { createSheet }
    }

    // MARK: - Network row

    private func networkRow(_ net: CLINetworkEntry) -> some View {
        HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "network")
                    .foregroundStyle(LassoColors.antBlue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(net.id)
                        .font(.body.weight(.medium))
                        .foregroundStyle(LassoColors.antTextPrimary)
                        .lineLimit(1)
                    Text(net.config?.mode ?? "—")
                        .font(.caption.monospaced())
                        .foregroundStyle(LassoColors.antTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(net.status?.ipv4Subnet ?? "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(net.status?.ipv4Subnet != nil ? LassoColors.antTextSecondary : LassoColors.antTextDisabled)
                .frame(width: 160, alignment: .leading)
            Text(net.status?.ipv6Subnet ?? "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(net.status?.ipv6Subnet != nil ? LassoColors.antTextSecondary : LassoColors.antTextDisabled)
                .frame(width: 160, alignment: .leading)
            Group {
                if let state = net.state {
                    Text(state)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(state == "active"
                            ? LassoColors.antSuccess.opacity(0.1)
                            : LassoColors.antTextSecondary.opacity(0.1))
                        .foregroundStyle(state == "active" ? LassoColors.antSuccess : LassoColors.antTextSecondary)
                        .clipShape(Capsule())
                } else {
                    Text("—")
                        .font(.body)
                        .foregroundStyle(LassoColors.antTextDisabled)
                }
            }
            .frame(width: 80, alignment: .leading)
            Button {
                Task { await viewModel.deleteNetwork(name: net.id) }
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LassoColors.antError)
                    .frame(width: 26, height: 26)
                    .background(LassoColors.antError.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, LassoSpacing.sm.rawValue)
        .background(hoveredNetID == net.id ? LassoColors.antBlueBg : LassoColors.antCardBg)
        .contentShape(Rectangle())
        .onHover { hoveredNetID = $0 ? net.id : nil }
        .animation(.easeOut(duration: 0.12), value: hoveredNetID == net.id)
        .pointerStyle(.link)
    }

    // MARK: - Create sheet

    private var createSheet: some View {
        VStack(spacing: LassoSpacing.lg.rawValue) {
            Text("Create Network").font(.title3.bold())
            TextField("Network name", text: $newNetworkName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { showCreateSheet = false }
                    .buttonStyle(GlassButtonStyle(.secondary))
                Spacer()
                Button("Create") {
                    let name = newNetworkName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    showCreateSheet = false
                    Task { await viewModel.createNetwork(name: name) }
                }
                .buttonStyle(GlassButtonStyle(.primary))
                .disabled(newNetworkName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(LassoSpacing.xl.rawValue)
        .frame(width: 360)
    }
}
