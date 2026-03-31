import SwiftUI
import LassoCore
import LassoData
import LassoUI

struct CoreLassoApp: App {

    @State private var dashboardViewModel: DashboardViewModel
    private let engine: HybridContainerEngine

    init() {
        // Auto-detect the best backend:
        //   • If container system start has installed a kernel AND the app has the
        //     com.apple.security.virtualization entitlement → directVZ (E/P core control)
        //   • Otherwise → containerCLI (works out of the box, no entitlements)
        let kernelURL = HybridContainerEngine.discoverKernelURL()
        let preferred: HybridContainerEngine.Backend = kernelURL != nil ? .directVZ : .containerCLI
        let engine = HybridContainerEngine(preferred: preferred, kernelURL: kernelURL)
        self.engine = engine
        let vm = DashboardViewModel(engine: engine)
        vm.setEngineLabel(preferred.rawValue)
        _dashboardViewModel = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: dashboardViewModel, engine: engine)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
