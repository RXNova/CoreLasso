import SwiftUI
import AppKit
import LassoCore
import LassoData

/// Root shell: NavigationSplitView + sidebar + routing.
/// All panel content lives in dedicated view files.
public struct DashboardView: View {

    @Bindable private var viewModel: DashboardViewModel
    private let engine: any LassoContainerEngine

    @Environment(\.md3Scheme) private var scheme
    @State private var showCreateSheet = false
    @State private var selection: SidebarItem? = .overview

    public init(viewModel: DashboardViewModel, engine: any LassoContainerEngine) {
        self.viewModel = viewModel
        self.engine = engine
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .md3Themed()
        .task {
            await viewModel.loadContainers()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateContainerView(engine: engine) {
                showCreateSheet = false
                Task { await viewModel.loadContainers() }
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

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(scheme.primary)
                    Text("CoreLasso")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(scheme.onSurface)
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)
            }

            Section {
                navRow(item: .overview,   icon: "house.fill",              label: "Home")
                containersNavRow
                navRow(item: .images,     icon: "square.stack.3d.up.fill", label: "Images",
                       badge: viewModel.images.isEmpty ? nil : "\(viewModel.images.count)")
                navRow(item: .volumes,    icon: "cylinder.split.1x2.fill", label: "Volumes")
                navRow(item: .networking, icon: "network",                 label: "Networking")
                navRow(item: .help,       icon: "questionmark.circle",     label: "Help")
                navRow(item: .settings,   icon: "gearshape",              label: "Settings")
            }
        }
        .listStyle(.sidebar)
        .tint(scheme.primary)
        .navigationTitle("")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }

    private func navRow(item: SidebarItem, icon: String, label: String, badge: String? = nil,
                        badgeBg: Color? = nil, badgeFg: Color? = nil) -> some View {
        return Label {
            HStack {
                Text(label)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(MD3Typography.labelSmall.monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(badgeBg ?? scheme.primaryContainer)
                        .foregroundStyle(badgeFg ?? scheme.onPrimaryContainer)
                        .clipShape(Capsule())
                }
            }
        } icon: {
            Image(systemName: icon)
        }
        .tag(item)
        .contentShape(Rectangle())
        .pointerStyle(.link)
    }

    private var containersNavRow: some View {
        let running = viewModel.containers.filter { $0.state == .running }.count
        let total = viewModel.containers.count
        let badge: String? = total == 0 ? nil : (running > 0 ? "\(running) running" : "\(total)")
        return navRow(
            item: .containers,
            icon: "shippingbox.fill",
            label: "Containers",
            badge: badge,
            badgeBg: running > 0 ? scheme.successContainer : scheme.primaryContainer,
            badgeFg: running > 0 ? scheme.onSuccessContainer : scheme.onPrimaryContainer
        )
    }

    // MARK: - Detail routing

    private var currentTitle: String {
        switch selection {
        case .overview, .none: "Overview"
        case .containers:      "Containers"
        case .container:       "Container Detail"
        case .images:          "Images"
        case .volumes:         "Volumes"
        case .networking:      "Networks"
        case .help:            "Help"
        case .settings:        "Settings"
        }
    }

    private var currentSubtitle: String {
        switch selection {
        case .overview, .none: "Container Runtime"
        case .containers:      "\(viewModel.containers.count) total"
        case .container:       ""
        case .images:          "\(viewModel.images.count) local"
        case .volumes:         "\(viewModel.volumes.count) volumes"
        case .networking:      "\(viewModel.networks.count) networks"
        case .help:            "Documentation"
        case .settings:        "Preferences"
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(spacing: 0) {
            // App-level gradient header
            appHeader

            ZStack {
                scheme.surfaceContainerLowest.ignoresSafeArea()

                switch selection {
            case .overview, .none:
                OverviewView(
                    viewModel: viewModel,
                    engine: engine,
                    onNewContainer: { showCreateSheet = true },
                    onPullImage: { selection = .images },
                    onSelectContainer: { id in selection = .container(id) },
                    onNavigate: { dest in
                        switch dest {
                        case .containers: selection = .containers
                        case .images:     selection = .images
                        case .volumes:    selection = .volumes
                        case .networking: selection = .networking
                        }
                    }
                )

            case .containers:
                if viewModel.isLoading {
                    ProgressView("Loading containers\u{2026}")
                        .foregroundStyle(scheme.onSurfaceVariant)
                } else {
                    ContainersView(
                        viewModel: viewModel,
                        engine: engine,
                        onNewContainer: { showCreateSheet = true },
                        onSelectContainer: { id in selection = .container(id) }
                    )
                }

            case .container(let id):
                if let container = viewModel.containers.first(where: { $0.id == id }) {
                    ContainerDetailHost(
                        container: container,
                        engine: engine,
                        volumes: viewModel.volumes,
                        onRecreate: {
                            selection = .containers
                            Task { await viewModel.loadContainers() }
                        }
                    )
                } else {
                    placeholderDetail(icon: "shippingbox", title: "Container not found", scheme: scheme)
                }

            case .images:
                ImagesView(viewModel: viewModel)

            case .volumes:
                VolumesView(viewModel: viewModel)

            case .networking:
                NetworkingView(viewModel: viewModel)

            case .help:
                HelpView()

            case .settings:
                placeholderDetail(icon: "gearshape", title: "Settings",
                                  subtitle: "App preferences coming soon.", scheme: scheme)
            }
        }
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Text(currentTitle)
                    .font(MD3Typography.titleMedium)
                    .foregroundStyle(.white)
                if !currentSubtitle.isEmpty {
                    Text("\u{00B7} \(currentSubtitle)")
                        .font(MD3Typography.bodySmall)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            Spacer()
            HStack(spacing: 6) {
                let isVZ = viewModel.engineLabel.contains("VZ") || viewModel.engineLabel.contains("Direct")
                Image(systemName: isVZ ? "cpu" : "terminal")
                    .font(MD3Typography.labelSmall)
                Text(viewModel.engineLabel)
                    .font(MD3Typography.labelSmall)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(.horizontal, LassoSpacing.lg.rawValue)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    scheme.primary.opacity(0.85),
                    scheme.primary.opacity(0.65),
                    scheme.tertiary.opacity(0.45)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}
