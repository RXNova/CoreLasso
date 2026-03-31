import SwiftUI
import LassoCore
import LassoData

struct VolumesView: View {

    @Bindable var viewModel: DashboardViewModel

    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newSize = ""
    @State private var newLabelEntries: [String] = []
    @State private var hoveredVolName: String?

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────────────
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Text("Volumes")
                    .font(.title2.bold())
                    .foregroundStyle(LassoColors.antTextPrimary)
                Spacer()
                Button {
                    Task { await viewModel.pruneVolumes() }
                } label: {
                    Label("Prune Unused", systemImage: "trash.slash")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(GlassButtonStyle(.secondary))
                .help("Remove volumes not in use by any container")
                Button {
                    newName = ""; newSize = ""; newLabelEntries = []
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
                Text("FORMAT").frame(width: 60, alignment: .leading)
                Text("SIZE").frame(width: 100, alignment: .trailing)
                Text("CREATED").frame(width: 110, alignment: .leading)
                Text("LABELS").frame(width: 180, alignment: .leading)
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
            if viewModel.volumes.isEmpty {
                Spacer()
                placeholderDetail(icon: "cylinder.split.1x2.fill", title: "No volumes",
                                  subtitle: "Create a volume to persist container data.")
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.volumes, id: \.name) { vol in
                            volumeRow(vol)
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

    // MARK: - Volume row

    private func volumeRow(_ vol: CLIVolumeEntry) -> some View {
        let inUse = viewModel.volumeIsInUse(vol.name)
        return HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "cylinder.split.1x2.fill")
                    .foregroundStyle(LassoColors.antBlue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(vol.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(LassoColors.antTextPrimary)
                        .lineLimit(1)
                    if let src = vol.source {
                        Text(src)
                            .font(.caption.monospaced())
                            .foregroundStyle(LassoColors.antTextDisabled)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(vol.format ?? "—")
                .font(.caption.monospaced())
                .foregroundStyle(LassoColors.antTextSecondary)
                .frame(width: 60, alignment: .leading)

            Text(vol.formattedSize ?? "—")
                .font(.body.monospaced())
                .foregroundStyle(vol.formattedSize != nil ? LassoColors.antTextSecondary : LassoColors.antTextDisabled)
                .frame(width: 100, alignment: .trailing)

            if let date = vol.createdDate {
                Text(relativeDate(date))
                    .font(.body)
                    .foregroundStyle(LassoColors.antTextSecondary)
                    .frame(width: 110, alignment: .leading)
            } else {
                Text("—")
                    .font(.body)
                    .foregroundStyle(LassoColors.antTextDisabled)
                    .frame(width: 110, alignment: .leading)
            }

            if let labels = vol.labels, !labels.isEmpty {
                Text(labels.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))
                    .font(.caption.monospaced())
                    .foregroundStyle(LassoColors.antTextSecondary)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
            } else {
                Text("—")
                    .font(.body)
                    .foregroundStyle(LassoColors.antTextDisabled)
                    .frame(width: 180, alignment: .leading)
            }

            Button {
                Task { await viewModel.deleteVolume(name: vol.name) }
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(inUse ? LassoColors.antTextDisabled : LassoColors.antError)
                    .frame(width: 26, height: 26)
                    .background((inUse ? LassoColors.antTextDisabled : LassoColors.antError).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(inUse)
            .help(inUse ? "Volume is in use by a container" : "Delete volume")
            .pointerStyle(.link)
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, LassoSpacing.sm.rawValue)
        .background(hoveredVolName == vol.name ? LassoColors.antBlueBg : LassoColors.antCardBg)
        .contentShape(Rectangle())
        .onHover { hoveredVolName = $0 ? vol.name : nil }
        .animation(.easeOut(duration: 0.12), value: hoveredVolName == vol.name)
        .pointerStyle(.link)
    }

    private var createSheet: some View {
        VStack(spacing: LassoSpacing.lg.rawValue) {
            Text("Create Volume").font(.title3.bold())

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Name").font(.subheadline.weight(.medium))
                    .foregroundStyle(LassoColors.antTextPrimary)
                TextField("my-volume", text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Size (optional)").font(.subheadline.weight(.medium))
                    .foregroundStyle(LassoColors.antTextPrimary)
                TextField("e.g. 10G", text: $newSize)
                    .textFieldStyle(.roundedBorder)
                Text("Supports K, M, G, T suffixes. Leave empty for default.")
                    .font(.caption)
                    .foregroundStyle(LassoColors.antTextSecondary)
            }

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                HStack {
                    Text("Labels (optional)").font(.subheadline.weight(.medium))
                        .foregroundStyle(LassoColors.antTextPrimary)
                    Spacer()
                    Button {
                        newLabelEntries.append("")
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(LassoColors.antBlue)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                }
                if newLabelEntries.isEmpty {
                    Text("No labels").font(.caption)
                        .foregroundStyle(LassoColors.antTextDisabled)
                } else {
                    ForEach(newLabelEntries.indices, id: \.self) { i in
                        HStack(spacing: LassoSpacing.xs.rawValue) {
                            TextField("key=value", text: $newLabelEntries[i])
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Button {
                                newLabelEntries.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(LassoColors.antError)
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { showCreateSheet = false }
                    .buttonStyle(GlassButtonStyle(.secondary))
                Spacer()
                Button("Create") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    let size = newSize.trimmingCharacters(in: .whitespaces)
                    let labels = newLabelEntries.filter { !$0.isEmpty }
                    showCreateSheet = false
                    Task { await viewModel.createVolume(name: name,
                                                        size: size.isEmpty ? nil : size,
                                                        labels: labels) }
                }
                .buttonStyle(GlassButtonStyle(.primary))
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(LassoSpacing.xl.rawValue)
        .frame(width: 400)
    }
}
