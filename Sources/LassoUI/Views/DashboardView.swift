import SwiftUI
import AppKit
import LassoCore
import LassoData

/// Root shell: NavigationSplitView + sidebar + routing.
/// All panel content lives in dedicated view files.
public struct DashboardView: View {

    @Bindable private var viewModel: DashboardViewModel
    private let engine: any LassoContainerEngine

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
                navRow(item: .overview,   icon: "house.fill",              label: "Home")
                containersNavRow
                navRow(item: .images,     icon: "square.stack.3d.up.fill", label: "Images",
                       badge: viewModel.images.isEmpty ? nil : "\(viewModel.images.count)")
                navRow(item: .volumes,    icon: "cylinder.split.1x2.fill", label: "Volumes")
                navRow(item: .networking, icon: "network",                 label: "Networking")
            }

            Section {
                navRow(item: .help,     icon: "questionmark.circle", label: "Help")
                navRow(item: .settings, icon: "gearshape",           label: "Settings")
            } header: {
                Spacer().frame(height: 340)
            }
        }
        .listStyle(.sidebar)
        .tint(LassoColors.antBlue)
        .searchable(text: $viewModel.searchText, prompt: "Search containers…")
        .navigationTitle("Core Lasso")
        .navigationSplitViewColumnWidth(min: 220, ideal: 240)
    }

    private func navRow(item: SidebarItem, icon: String, label: String, badge: String? = nil,
                        badgeBg: Color = LassoColors.antBlueBg, badgeFg: Color = LassoColors.antBlue) -> some View {
        return Label {
            HStack {
                Text(label)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeBg)
                        .foregroundStyle(badgeFg)
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

    /// Specialised sidebar row for Containers — shows running count in green
    /// when any containers are running, total in lavender otherwise.
    private var containersNavRow: some View {
        let running = viewModel.containers.filter { $0.state == .running }.count
        let total = viewModel.containers.count
        let badge: String? = total == 0 ? nil : (running > 0 ? "\(running) running" : "\(total)")
        return navRow(
            item: .containers,
            icon: "shippingbox.fill",
            label: "Containers",
            badge: badge,
            badgeBg: running > 0 ? LassoColors.antSuccessBg : LassoColors.antBlueBg,
            badgeFg: running > 0 ? LassoColors.antSuccess    : LassoColors.antBlue
        )
    }

    // MARK: - Detail routing

    @ViewBuilder
    private var detail: some View {
        ZStack {
            LassoColors.antPageBg.ignoresSafeArea()

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
                    ProgressView("Loading containers…")
                        .foregroundStyle(LassoColors.antTextSecondary)
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
                    placeholderDetail(icon: "shippingbox", title: "Container not found")
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
                                  subtitle: "App preferences coming soon.")
            }
        }
    }
}
