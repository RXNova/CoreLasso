import SwiftUI
import LassoCore
import LassoData

struct VolumesView: View {

    @Bindable var viewModel: DashboardViewModel
    @Environment(\.md3Scheme) private var scheme

    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newSize = ""
    @State private var newLabelEntries: [String] = []
    @State private var hoveredVolName: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Spacer()
                Button {
                    Task { await viewModel.pruneVolumes() }
                } label: {
                    Label("Prune Unused", systemImage: "trash.slash")
                }
                .buttonStyle(MD3ButtonStyle(.tonal))
                .help("Remove volumes not in use by any container")
                Button {
                    newName = ""; newSize = ""; newLabelEntries = []
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
                Text("FORMAT").frame(width: 60, alignment: .leading)
                Text("SIZE").frame(width: 100, alignment: .trailing)
                Text("CREATED").frame(width: 110, alignment: .leading)
                Text("LABELS").frame(width: 180, alignment: .leading)
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
            if viewModel.volumes.isEmpty {
                Spacer()
                placeholderDetail(icon: "cylinder.split.1x2.fill", title: "No volumes",
                                  subtitle: "Create a volume to persist container data.", scheme: scheme)
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
                .background(scheme.surface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(scheme.surfaceContainerLowest)
        .sheet(isPresented: $showCreateSheet) { createSheet }
    }

    // MARK: - Volume row

    private func volumeRow(_ vol: CLIVolumeEntry) -> some View {
        let inUse = viewModel.volumeIsInUse(vol.name)
        return HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "cylinder.split.1x2.fill")
                    .foregroundStyle(scheme.primary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(vol.name)
                        .font(MD3Typography.bodyLarge)
                        .foregroundStyle(scheme.onSurface)
                        .lineLimit(1)
                    if let src = vol.source {
                        Text(src)
                            .font(.caption.monospaced())
                            .foregroundStyle(scheme.onSurfaceVariant.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(vol.format ?? "\u{2014}")
                .font(.caption.monospaced())
                .foregroundStyle(scheme.onSurfaceVariant)
                .frame(width: 60, alignment: .leading)

            Text(vol.formattedSize ?? "\u{2014}")
                .font(MD3Typography.bodyMedium.monospaced())
                .foregroundStyle(vol.formattedSize != nil ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.opacity(0.5))
                .frame(width: 100, alignment: .trailing)

            if let date = vol.createdDate {
                Text(relativeDate(date))
                    .font(MD3Typography.bodyMedium)
                    .foregroundStyle(scheme.onSurfaceVariant)
                    .frame(width: 110, alignment: .leading)
            } else {
                Text("\u{2014}")
                    .font(MD3Typography.bodyMedium)
                    .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
                    .frame(width: 110, alignment: .leading)
            }

            if let labels = vol.labels, !labels.isEmpty {
                Text(labels.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))
                    .font(.caption.monospaced())
                    .foregroundStyle(scheme.onSurfaceVariant)
                    .lineLimit(1)
                    .frame(width: 180, alignment: .leading)
            } else {
                Text("\u{2014}")
                    .font(MD3Typography.bodyMedium)
                    .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
                    .frame(width: 180, alignment: .leading)
            }

            Button {
                Task { await viewModel.deleteVolume(name: vol.name) }
            } label: {
                Image(systemName: "trash")
                    .font(MD3Typography.labelMedium)
                    .foregroundStyle(inUse ? scheme.onSurfaceVariant.opacity(0.5) : scheme.error)
                    .frame(width: 26, height: 26)
                    .background((inUse ? scheme.onSurfaceVariant.opacity(0.5) : scheme.error).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue))
            }
            .buttonStyle(.plain)
            .disabled(inUse)
            .help(inUse ? "Volume is in use by a container" : "Delete volume")
            .pointerStyle(.link)
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, LassoSpacing.sm.rawValue)
        .background(hoveredVolName == vol.name ? scheme.primary.opacity(0.08) : scheme.surface)
        .contentShape(Rectangle())
        .onHover { hoveredVolName = $0 ? vol.name : nil }
        .animation(.easeOut(duration: 0.12), value: hoveredVolName == vol.name)
        .pointerStyle(.link)
    }

    private var createSheet: some View {
        VStack(spacing: LassoSpacing.lg.rawValue) {
            Text("Create Volume")
                .font(MD3Typography.titleLarge)
                .foregroundStyle(scheme.onSurface)

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Name").font(MD3Typography.titleSmall)
                    .foregroundStyle(scheme.onSurface)
                TextField("my-volume", text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Size (optional)").font(MD3Typography.titleSmall)
                    .foregroundStyle(scheme.onSurface)
                TextField("e.g. 10G", text: $newSize)
                    .textFieldStyle(.roundedBorder)
                Text("Supports K, M, G, T suffixes. Leave empty for default.")
                    .font(MD3Typography.bodySmall)
                    .foregroundStyle(scheme.onSurfaceVariant)
            }

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                HStack {
                    Text("Labels (optional)").font(MD3Typography.titleSmall)
                        .foregroundStyle(scheme.onSurface)
                    Spacer()
                    Button {
                        newLabelEntries.append("")
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                            .font(MD3Typography.labelMedium)
                            .foregroundStyle(scheme.primary)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                }
                if newLabelEntries.isEmpty {
                    Text("No labels").font(MD3Typography.bodySmall)
                        .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
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
                                    .foregroundStyle(scheme.error)
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { showCreateSheet = false }
                    .buttonStyle(MD3ButtonStyle(.outlined))
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
                .buttonStyle(MD3ButtonStyle(.filled))
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(LassoSpacing.xl.rawValue)
        .frame(width: 400)
    }
}
