import SwiftUI
import LassoCore
import LassoData

struct ImagesView: View {

    @Bindable var viewModel: DashboardViewModel
    @Environment(\.md3Scheme) private var scheme

    @State private var showPullSheet = false
    @State private var showBuildSheet = false
    @State private var buildContextPath = ""
    @State private var buildTag = ""
    @State private var buildDockerfilePath = ""
    @State private var pullRegistry: PullRegistry = .dockerHub
    @State private var pullInput = ""
    @State private var searchResults: [DockerHubResult] = []
    @State private var isSearching = false
    @State private var deleteImagePending: ImageInfo?
    @State private var hoveredRef: String?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(MD3Typography.labelMedium)
                        .foregroundStyle(scheme.onSurfaceVariant)
                    TextField("Filter images\u{2026}", text: $viewModel.imageSearchText)
                        .textFieldStyle(.plain)
                        .frame(width: 180)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(scheme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue, style: .continuous))
                Button {
                    buildContextPath = ""
                    buildTag = ""
                    buildDockerfilePath = ""
                    showBuildSheet = true
                } label: {
                    Label("Build", systemImage: "hammer.circle")
                }
                .buttonStyle(MD3ButtonStyle(.tonal))
                Button {
                    pullInput = ""
                    pullRegistry = .dockerHub
                    showPullSheet = true
                } label: {
                    Label("Pull Image", systemImage: "arrow.down.circle")
                }
                .buttonStyle(MD3ButtonStyle(.filled))
            }
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.md.rawValue)
            .background(scheme.surface)
            .overlay(alignment: .bottom) { Divider() }

            // Column headers
            HStack {
                Text("REFERENCE").frame(maxWidth: .infinity, alignment: .leading)
                Text("TAG").frame(width: 120, alignment: .leading)
                Text("SIZE").frame(width: 80, alignment: .trailing)
                Text("DIGEST").frame(width: 160, alignment: .leading)
                Spacer().frame(width: 60)
            }
            .font(MD3Typography.labelSmall)
            .tracking(0.6)
            .foregroundStyle(scheme.onSurfaceVariant)
            .padding(.horizontal, LassoSpacing.lg.rawValue)
            .padding(.vertical, LassoSpacing.sm.rawValue)
            .background(scheme.surfaceContainerLow)
            .overlay(alignment: .bottom) { Divider() }

            // Content
            let hasPull = viewModel.pullingReference != nil
            let hasBuild = viewModel.buildingTag != nil
            if viewModel.images.isEmpty && !hasPull && !hasBuild {
                Spacer()
                placeholderDetail(icon: "square.stack.3d.up", title: "No local images",
                                  subtitle: "Pull an image to get started.", scheme: scheme)
                Spacer()
            } else if viewModel.filteredImages.isEmpty && !hasPull && !hasBuild {
                Spacer()
                placeholderDetail(icon: "magnifyingglass", title: "No results",
                                  subtitle: "No images match \"\(viewModel.imageSearchText)\"", scheme: scheme)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if let building = viewModel.buildingTag {
                            buildingRow(tag: building)
                            Divider().padding(.leading, LassoSpacing.lg.rawValue)
                        }
                        if let pulling = viewModel.pullingReference {
                            pullingRow(reference: pulling)
                            Divider().padding(.leading, LassoSpacing.lg.rawValue)
                        }
                        ForEach(viewModel.filteredImages) { image in
                            imageRow(image)
                            Divider().padding(.leading, LassoSpacing.lg.rawValue)
                        }
                    }
                }
                .background(scheme.surface)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(scheme.surfaceContainerLowest)
        .sheet(isPresented: $showPullSheet) { pullSheet }
        .sheet(isPresented: $showBuildSheet) { buildSheet }
        .confirmationDialog(
            "Delete \"\(deleteImagePending?.reference ?? "")\"?",
            isPresented: .init(
                get: { deleteImagePending != nil },
                set: { if !$0 { deleteImagePending = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let ref = deleteImagePending?.reference {
                    Task { await viewModel.deleteImage(reference: ref) }
                }
                deleteImagePending = nil
            }
            Button("Cancel", role: .cancel) { deleteImagePending = nil }
        } message: {
            Text("This image will be removed from local storage. This cannot be undone.")
        }
    }

    // MARK: - Image row

    private func imageRow(_ image: ImageInfo) -> some View {
        let inUse = viewModel.imageIsInUse(image.reference)
        return HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(scheme.primary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(image.name)
                        .font(MD3Typography.bodyLarge)
                        .foregroundStyle(scheme.onSurface)
                        .lineLimit(1)
                    Text(image.reference)
                        .font(.caption.monospaced())
                        .foregroundStyle(scheme.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Text(image.tag ?? "latest")
                    .font(.caption.monospaced())
                    .foregroundStyle(scheme.onSurfaceVariant)
                if inUse {
                    Text("IN USE")
                        .font(MD3Typography.labelSmall)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(scheme.successContainer)
                        .foregroundStyle(scheme.onSuccessContainer)
                        .clipShape(Capsule())
                }
            }
            .frame(width: 120, alignment: .leading)

            Text(image.size ?? "\u{2014}")
                .font(MD3Typography.bodyMedium.monospaced())
                .foregroundStyle(scheme.onSurfaceVariant)
                .frame(width: 80, alignment: .trailing)

            if let digest = image.digest {
                Text(String(digest.prefix(20)) + "\u{2026}")
                    .font(.caption.monospaced())
                    .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
                    .frame(width: 160, alignment: .leading)
            } else {
                Text("\u{2014}")
                    .font(MD3Typography.bodyMedium)
                    .foregroundStyle(scheme.onSurfaceVariant.opacity(0.5))
                    .frame(width: 160, alignment: .leading)
            }

            Button { deleteImagePending = image } label: {
                Image(systemName: "trash")
                    .font(MD3Typography.labelMedium)
                    .foregroundStyle(inUse ? scheme.onSurfaceVariant.opacity(0.5) : scheme.error)
                    .frame(width: 26, height: 26)
                    .background((inUse ? scheme.onSurfaceVariant.opacity(0.5) : scheme.error).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue))
            }
            .buttonStyle(.plain)
            .disabled(inUse)
            .help(inUse ? "Image is in use by a container" : "Delete image")
            .pointerStyle(.link)
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, 8)
        .background(hoveredRef == image.reference ? scheme.primary.opacity(0.08) : scheme.surface)
        .contentShape(Rectangle())
        .onHover { hoveredRef = $0 ? image.reference : nil }
        .animation(.easeOut(duration: 0.12), value: hoveredRef == image.reference)
        .pointerStyle(.link)
    }

    // MARK: - Building row

    private func buildingRow(tag: String) -> some View {
        HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "hammer.fill")
                    .foregroundStyle(scheme.warning.opacity(0.7))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tag.isEmpty ? "Unnamed image" : tag)
                        .font(MD3Typography.bodyLarge)
                        .foregroundStyle(scheme.onSurface)
                        .lineLimit(1)
                    Text("Building from Dockerfile\u{2026}")
                        .font(.caption.monospaced())
                        .foregroundStyle(scheme.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("Building\u{2026}")
                    .font(MD3Typography.bodySmall)
                    .foregroundStyle(scheme.onSurfaceVariant)
                ProgressView()
                    .controlSize(.small)
                    .tint(scheme.warning)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, 8)
    }

    // MARK: - Pulling row

    private func pullingRow(reference: String) -> some View {
        HStack {
            HStack(spacing: LassoSpacing.sm.rawValue) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(scheme.primary.opacity(0.45))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(shortPullName(reference))
                        .font(MD3Typography.bodyLarge)
                        .foregroundStyle(scheme.onSurface)
                        .lineLimit(1)
                    Text(reference)
                        .font(.caption.monospaced())
                        .foregroundStyle(scheme.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("Pulling\u{2026}")
                    .font(MD3Typography.bodySmall)
                    .foregroundStyle(scheme.onSurfaceVariant)
                ProgressView()
                    .controlSize(.small)
                    .tint(scheme.primary)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, 8)
    }

    private func shortPullName(_ reference: String) -> String {
        let noScheme = reference.hasPrefix("https://") ? String(reference.dropFirst(8)) : reference
        let parts = noScheme.split(separator: "/")
        return parts.last.map(String.init) ?? reference
    }

    // MARK: - Build sheet

    private var buildSheet: some View {
        VStack(alignment: .leading, spacing: LassoSpacing.lg.rawValue) {
            Text("Build Image")
                .font(MD3Typography.titleLarge)
                .foregroundStyle(scheme.onSurface)

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Build Context").font(MD3Typography.titleSmall)
                    .foregroundStyle(scheme.onSurface)
                HStack(spacing: LassoSpacing.sm.rawValue) {
                    TextField("/path/to/context", text: $buildContextPath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.prompt = "Select"
                        if panel.runModal() == .OK, let url = panel.url {
                            buildContextPath = url.path
                            if buildDockerfilePath.isEmpty {
                                let candidate = url.appendingPathComponent("Dockerfile").path
                                if FileManager.default.fileExists(atPath: candidate) {
                                    buildDockerfilePath = candidate
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(MD3ButtonStyle(.tonal))
                }
                Text("Directory containing your Dockerfile")
                    .font(MD3Typography.bodySmall)
                    .foregroundStyle(scheme.onSurfaceVariant)
            }

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Dockerfile (optional)").font(MD3Typography.titleSmall)
                    .foregroundStyle(scheme.onSurface)
                HStack(spacing: LassoSpacing.sm.rawValue) {
                    TextField("Leave empty for <context>/Dockerfile", text: $buildDockerfilePath)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.allowedContentTypes = []
                        panel.prompt = "Select"
                        if panel.runModal() == .OK, let url = panel.url {
                            buildDockerfilePath = url.path
                        }
                    } label: {
                        Image(systemName: "doc")
                    }
                    .buttonStyle(MD3ButtonStyle(.tonal))
                }
            }

            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Image Tag").font(MD3Typography.titleSmall)
                    .foregroundStyle(scheme.onSurface)
                TextField("myapp:latest", text: $buildTag)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") { showBuildSheet = false }
                    .buttonStyle(MD3ButtonStyle(.outlined))
                Spacer()
                Button("Build") {
                    let ctx = buildContextPath.trimmingCharacters(in: .whitespaces)
                    let tag = buildTag.trimmingCharacters(in: .whitespaces)
                    let df: String? = buildDockerfilePath.trimmingCharacters(in: .whitespaces).isEmpty
                        ? nil : buildDockerfilePath.trimmingCharacters(in: .whitespaces)
                    showBuildSheet = false
                    Task { await viewModel.buildImage(contextPath: ctx, tag: tag, dockerfile: df) }
                }
                .buttonStyle(MD3ButtonStyle(.filled))
                .disabled(buildContextPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(LassoSpacing.xl.rawValue)
        .frame(width: 480)
    }

    // MARK: - Pull sheet

    private var pullReference: String {
        let input = pullInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return "" }
        switch pullRegistry {
        case .dockerHub:
            if input.contains("/") || input.hasPrefix("docker.io") { return input }
            let hasTag = input.contains(":")
            let name = hasTag ? String(input.split(separator: ":").first ?? Substring(input)) : input
            let tag  = hasTag ? String(input.split(separator: ":").last  ?? "latest") : "latest"
            return "docker.io/library/\(name):\(tag)"
        case .custom:
            return input
        default:
            if input.hasPrefix(pullRegistry.prefix) { return input }
            return pullRegistry.prefix + input
        }
    }

    private var pullSheet: some View {
        VStack(alignment: .leading, spacing: LassoSpacing.lg.rawValue) {
            Text("Pull Image")
                .font(MD3Typography.titleLarge)
                .foregroundStyle(scheme.onSurface)

            // Registry chips
            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Registry").font(MD3Typography.titleSmall)
                    .foregroundStyle(scheme.onSurface)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: LassoSpacing.xs.rawValue) {
                    ForEach(PullRegistry.allCases) { reg in
                        MD3FilterChip(
                            reg.rawValue,
                            icon: reg.icon,
                            isSelected: pullRegistry == reg
                        ) {
                            pullRegistry = reg
                        }
                    }
                }
            }

            // Image input + search results
            VStack(alignment: .leading, spacing: LassoSpacing.xs.rawValue) {
                Text("Image").font(MD3Typography.titleSmall)
                    .foregroundStyle(scheme.onSurface)
                TextField(pullRegistry.placeholder, text: $pullInput)
                    .textFieldStyle(.roundedBorder)

                if pullRegistry == .dockerHub {
                    if isSearching {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Searching Docker Hub\u{2026}")
                                .font(MD3Typography.bodySmall)
                                .foregroundStyle(scheme.onSurfaceVariant)
                        }
                        .padding(.top, 2)
                    } else if !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults) { result in
                                Button {
                                    pullInput = result.name
                                    searchResults = []
                                } label: {
                                    HStack(spacing: LassoSpacing.sm.rawValue) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(result.name)
                                                    .font(MD3Typography.bodyLarge)
                                                    .foregroundStyle(scheme.onSurface)
                                                if result.isOfficial {
                                                    Text("OFFICIAL")
                                                        .font(MD3Typography.labelSmall)
                                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                                        .background(scheme.primaryContainer)
                                                        .foregroundStyle(scheme.onPrimaryContainer)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            if let desc = result.description, !desc.isEmpty {
                                                Text(desc)
                                                    .font(MD3Typography.bodySmall)
                                                    .foregroundStyle(scheme.onSurfaceVariant)
                                                    .lineLimit(2)
                                            }
                                        }
                                        Spacer()
                                        if result.starCount > 0 {
                                            Label(formatStarCount(result.starCount), systemImage: "star.fill")
                                                .font(MD3Typography.labelSmall)
                                                .foregroundStyle(scheme.onSurfaceVariant.opacity(0.6))
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .pointerStyle(.link)
                                if result.id != searchResults.last?.id {
                                    Divider().padding(.leading, 10)
                                }
                            }
                        }
                        .background(scheme.surfaceContainerHigh)
                        .clipShape(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: LassoRadius.md.rawValue, style: .continuous)
                            .stroke(scheme.outlineVariant, lineWidth: 0.5))
                    }
                }

                if !pullReference.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(MD3Typography.bodySmall).foregroundStyle(scheme.primary)
                        Text(pullReference)
                            .font(.caption.monospaced())
                            .foregroundStyle(scheme.primary)
                            .lineLimit(1)
                    }
                }
            }

            HStack {
                Button("Cancel") { showPullSheet = false }
                    .buttonStyle(MD3ButtonStyle(.outlined))
                Spacer()
                Button("Pull Image") {
                    let ref = pullReference
                    showPullSheet = false
                    Task { await viewModel.pullImage(reference: ref) }
                }
                .buttonStyle(MD3ButtonStyle(.filled))
                .disabled(pullReference.isEmpty)
            }
        }
        .padding(LassoSpacing.xl.rawValue)
        .frame(width: 420)
        .task(id: pullInput + pullRegistry.id) {
            guard pullRegistry == .dockerHub else { searchResults = []; return }
            let q = pullInput.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2, !q.contains(":"), !q.contains("/") else { searchResults = []; return }
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            isSearching = true
            searchResults = await fetchDockerHubResults(query: q)
            isSearching = false
        }
    }

    // MARK: - Docker Hub search

    private func fetchDockerHubResults(query: String) async -> [DockerHubResult] {
        var comps = URLComponents(string: "https://hub.docker.com/v2/search/repositories/")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page_size", value: "8")
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        struct Response: Decodable {
            struct Item: Decodable {
                var repo_name: String
                var short_description: String?
                var is_official: Bool?
                var star_count: Int?
            }
            var results: [Item]
        }
        guard let resp = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        return resp.results.map {
            DockerHubResult(name: $0.repo_name, description: $0.short_description,
                            isOfficial: $0.is_official ?? false, starCount: $0.star_count ?? 0)
        }
    }

    private func formatStarCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1_000) }
        return "\(count)"
    }

    // MARK: - Nested types

    enum PullRegistry: String, CaseIterable, Identifiable {
        case dockerHub  = "Docker Hub"
        case ghcr       = "GitHub (GHCR)"
        case gar        = "Google (GAR)"
        case ecr        = "AWS ECR Public"
        case quay       = "Quay.io"
        case custom     = "Custom"
        var id: String { rawValue }
        var prefix: String {
            switch self {
            case .dockerHub: return ""
            case .ghcr:      return "ghcr.io/"
            case .gar:       return "us-docker.pkg.dev/"
            case .ecr:       return "public.ecr.aws/"
            case .quay:      return "quay.io/"
            case .custom:    return ""
            }
        }
        var placeholder: String {
            switch self {
            case .dockerHub: return "ubuntu:22.04"
            case .ghcr:      return "owner/image:tag"
            case .gar:       return "project/repo/image:tag"
            case .ecr:       return "library/ubuntu:24.04"
            case .quay:      return "prometheus/prometheus:latest"
            case .custom:    return "registry.example.com/repo/image:tag"
            }
        }
        var icon: String {
            switch self {
            case .dockerHub: return "shippingbox.fill"
            case .ghcr:      return "cat"
            case .gar:       return "g.circle.fill"
            case .ecr:       return "a.circle.fill"
            case .quay:      return "bird"
            case .custom:    return "server.rack"
            }
        }
    }

    struct DockerHubResult: Identifiable {
        var id: String { name }
        var name: String
        var description: String?
        var isOfficial: Bool
        var starCount: Int
    }
}
