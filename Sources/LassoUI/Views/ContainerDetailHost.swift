import SwiftUI
import LassoCore
import LassoData

/// Keeps a stable `ContainerDetailViewModel` alive across `DashboardView`
/// re-renders. Created once per container ID; only data is patched on refresh.
struct ContainerDetailHost: View {

    let container: ContainerInfo
    let engine: any LassoContainerEngine
    let volumes: [CLIVolumeEntry]
    let onRecreate: () -> Void

    @State private var vm: ContainerDetailViewModel

    init(container: ContainerInfo,
         engine: any LassoContainerEngine,
         volumes: [CLIVolumeEntry],
         onRecreate: @escaping () -> Void) {
        self.container = container
        self.engine = engine
        self.volumes = volumes
        self.onRecreate = onRecreate
        _vm = State(initialValue: ContainerDetailViewModel(container: container, engine: engine))
    }

    var body: some View {
        ContainerDetailView(viewModel: vm, onRecreate: onRecreate)
            .onChange(of: container) { _, updated in
                vm.container = updated
            }
            .onChange(of: volumes) { _, updated in
                vm.volumeSizes = volumeSizeMap(updated)
            }
            .onAppear {
                vm.volumeSizes = volumeSizeMap(volumes)
            }
    }

    private func volumeSizeMap(_ entries: [CLIVolumeEntry]) -> [String: UInt64] {
        Dictionary(uniqueKeysWithValues: entries.compactMap {
            guard let s = $0.sizeInBytes else { return nil }
            return ($0.name, s)
        })
    }
}
