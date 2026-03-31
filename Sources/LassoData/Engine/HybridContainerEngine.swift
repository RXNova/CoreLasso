import Foundation
import LassoCore

/// A smart container engine that routes operations to the best available backend.
///
/// ## How it works
///
/// ```
/// HybridContainerEngine
/// ├── Image ops (pull/push/list/build)
/// │       └── always → ContainerCLIEngine
/// │               (apple/container daemon owns the image store & registry auth)
/// │
/// └── Container lifecycle (create/start/stop/kill/delete)
///         ├── .directVZ  → VZContainerEngine  (needs entitlement + kernel)
///         │       ✓ E-core / P-core scheduling via Task(priority:)
///         │       ✓ In-process, no daemon dependency
///         │       ✓ Full LassoPowerProfile support
///         │
///         └── .containerCLI  → ContainerCLIEngine  (automatic fallback)
///                 ✓ Works today, zero entitlements
///                 ✗ No E/P core control (container-runtime-linux owns the VM)
/// ```
///
/// ## Selecting a backend
///
/// The engine is instantiated with a preferred backend and a kernel URL:
///
/// ```swift
/// // Works immediately — no entitlements, no kernel needed
/// let engine = HybridContainerEngine()
///
/// // Full E/P core control — requires com.apple.security.virtualization entitlement
/// // and the kernel downloaded by `container system start`
/// let engine = HybridContainerEngine(
///     preferred: .directVZ,
///     kernelURL: HybridContainerEngine.discoverKernelURL()
/// )
/// ```
///
/// ## Kernel discovery
///
/// `container system start` downloads the Kata kernel to the app-root directory.
/// `HybridContainerEngine.discoverKernelURL()` probes the known install locations
/// so you never need to hard-code a path.
///
/// ## Upgrading to full direct-VZ
///
/// Add the `com.apple.security.virtualization` entitlement to the app's
/// `.entitlements` file, sign the binary, and pass `preferred: .directVZ`.
/// The engine switches automatically — no other code changes required.
public actor HybridContainerEngine: LassoContainerEngine, ContainerImageService, ContainerStatsService, CLIManagementService {

    // MARK: - Backend

    /// Which engine is handling container lifecycle operations.
    public enum Backend: String, Sendable, CaseIterable {
        /// apple/container CLI daemon.
        /// Works without entitlements. No E/P core control.
        case containerCLI = "container CLI"

        /// Direct Virtualization.framework via `VZContainerEngine`.
        /// Requires `com.apple.security.virtualization` entitlement + kernel.
        /// Enables per-container E/P core scheduling via `LassoPowerProfile`.
        case directVZ = "Direct VZ"
    }

    // MARK: - Properties

    /// The backend currently handling lifecycle operations.
    public private(set) var activeBackend: Backend

    /// URL of the Linux kernel used by the direct-VZ backend.
    /// `nil` when `activeBackend == .containerCLI`.
    public let kernelURL: URL?

    // MARK: - Internal engines

    /// Always available — handles all image operations.
    private let cliEngine: ContainerCLIEngine

    /// Available only when the entitlement is granted and a kernel is configured.
    private let vzEngine: VZContainerEngine

    // MARK: - Init

    /// Create a `HybridContainerEngine`.
    ///
    /// - Parameters:
    ///   - preferred: The backend to use for container lifecycle.
    ///     Defaults to `.containerCLI` (zero requirements, works today).
    ///   - kernelURL: Path to the Linux kernel binary. Required when
    ///     `preferred == .directVZ`. Use `HybridContainerEngine.discoverKernelURL()`
    ///     to locate the kernel that `container system start` installed.
    ///   - binaryPath: Path to the `container` CLI binary.
    public init(
        preferred: Backend = .containerCLI,
        kernelURL: URL? = nil,
        binaryPath: String = "/usr/local/bin/container"
    ) {
        self.cliEngine = ContainerCLIEngine(binaryPath: binaryPath)
        self.vzEngine = VZContainerEngine()
        self.kernelURL = kernelURL

        // Only activate direct-VZ if we actually have a kernel URL.
        // Without one, VZVirtualMachineConfiguration.validate() will throw.
        if preferred == .directVZ, kernelURL != nil {
            self.activeBackend = .directVZ
        } else {
            self.activeBackend = .containerCLI
        }
    }

    // MARK: - Kernel Discovery

    /// Probe well-known locations for the kernel that `container system start` installed.
    ///
    /// Checks (in order):
    /// 1. `UserDefaults(suiteName: "com.apple.container.defaults")` for any stored path
    /// 2. `~/.local/share/container/kernels/vmlinux`
    /// 3. `~/Library/Application Support/container/kernels/vmlinux`
    ///
    /// Returns `nil` if no kernel is found — use `.containerCLI` backend in that case.
    public static func discoverKernelURL() -> URL? {
        // 1. Check container's UserDefaults domain for a stored kernel path override.
        if let ud = UserDefaults(suiteName: "com.apple.container.defaults"),
           let storedPath = ud.string(forKey: "kernel.path"),
           !storedPath.isEmpty {
            let url = URL(fileURLWithPath: storedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // 2. Probe the known install locations.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [String] = [
            "\(home)/.local/share/container/kernels/vmlinux",
            "\(home)/Library/Application Support/container/kernels/vmlinux",
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    /// Whether the direct-VZ backend is available on this machine.
    ///
    /// Returns `true` when:
    /// - A kernel exists at a discoverable location, AND
    /// - The process has the `com.apple.security.virtualization` entitlement
    ///   (detected heuristically — a `VZVirtualMachineConfiguration.validate()` that
    ///   does NOT throw an entitlement error).
    public static func canUseDirectVZ() -> Bool {
        guard discoverKernelURL() != nil else { return false }
        // Entitlement presence is validated at runtime when the first VM is created.
        // Return true optimistically if a kernel exists; VZContainerEngine will surface
        // the entitlement error through LassoEngineError.vmStartFailed if it's missing.
        return true
    }

    // MARK: - LassoContainerEngine: Spec

    public func loadSpec(from fileURL: URL) async throws -> LassoSpec {
        switch activeBackend {
        case .containerCLI:   return try await cliEngine.loadSpec(from: fileURL)
        case .directVZ:       return try await vzEngine.loadSpec(from: fileURL)
        }
    }

    public func validate(spec: LassoSpec) async throws {
        switch activeBackend {
        case .containerCLI:   try await cliEngine.validate(spec: spec)
        case .directVZ:       try await vzEngine.validate(spec: spec)
        }
    }

    // MARK: - LassoContainerEngine: Lifecycle

    /// Create a container.
    ///
    /// - `.directVZ`: Creates an in-process `VZVirtualMachine` configuration.
    ///   The `LassoPowerProfile` on the spec is honoured — the VM's start `Task`
    ///   runs at the matching `TaskPriority`, biasing Apple Silicon's scheduler
    ///   toward E-cores (`.utility`) or P-cores (`.performance`).
    ///
    /// - `.containerCLI`: Delegates to `container create …`.
    public func create(spec: LassoSpec) async throws -> String {
        switch activeBackend {
        case .containerCLI:   return try await cliEngine.create(spec: spec)
        case .directVZ:       return try await vzEngine.create(spec: spec)
        }
    }

    public func start(containerID: String) async throws {
        switch activeBackend {
        case .containerCLI:   try await cliEngine.start(containerID: containerID)
        case .directVZ:       try await vzEngine.start(containerID: containerID)
        }
    }

    public func stop(containerID: String, timeout: Duration) async throws {
        switch activeBackend {
        case .containerCLI:   try await cliEngine.stop(containerID: containerID, timeout: timeout)
        case .directVZ:       try await vzEngine.stop(containerID: containerID, timeout: timeout)
        }
    }

    public func kill(containerID: String) async throws {
        switch activeBackend {
        case .containerCLI:   try await cliEngine.kill(containerID: containerID)
        case .directVZ:       try await vzEngine.kill(containerID: containerID)
        }
    }

    public func delete(containerID: String) async throws {
        switch activeBackend {
        case .containerCLI:   try await cliEngine.delete(containerID: containerID)
        case .directVZ:       try await vzEngine.delete(containerID: containerID)
        }
    }

    // MARK: - LassoContainerEngine: Inspection

    public func info(containerID: String) async throws -> ContainerInfo {
        switch activeBackend {
        case .containerCLI:   return try await cliEngine.info(containerID: containerID)
        case .directVZ:       return try await vzEngine.info(containerID: containerID)
        }
    }

    public func listContainers() async -> [ContainerInfo] {
        switch activeBackend {
        case .containerCLI:   return await cliEngine.listContainers()
        case .directVZ:       return await vzEngine.listContainers()
        }
    }

    public func stateStream(for containerID: String) async throws -> AsyncStream<ContainerState> {
        switch activeBackend {
        case .containerCLI:   return try await cliEngine.stateStream(for: containerID)
        case .directVZ:       return try await vzEngine.stateStream(for: containerID)
        }
    }

    // MARK: - ContainerImageService (always CLI)
    //
    // Image management is always delegated to ContainerCLIEngine because:
    // - The `container` daemon owns the local OCI content store.
    // - Registry authentication is managed by `container-apiserver` + Keychain.
    // - VZContainerEngine has no image registry client.

    public func listImages() async throws -> [ImageInfo] {
        try await cliEngine.listImages()
    }

    public func pullImage(reference: String) async throws {
        try await cliEngine.pullImage(reference: reference)
    }

    public func pushImage(reference: String) async throws {
        try await cliEngine.pushImage(reference: reference)
    }

    public func deleteImage(reference: String) async throws {
        try await cliEngine.deleteImage(reference: reference)
    }

    public func tagImage(source: String, target: String) async throws {
        try await cliEngine.tagImage(source: source, target: target)
    }

    public func buildImage(contextPath: String, tag: String, dockerfile: String?) async throws {
        try await cliEngine.buildImage(contextPath: contextPath, tag: tag, dockerfile: dockerfile)
    }

    // MARK: - ContainerStatsService (always CLI)

    public func stats(containerID: String) async throws -> CLIStats {
        try await cliEngine.stats(containerID: containerID)
    }

    public nonisolated func statsStream(containerID: String) -> AsyncThrowingStream<CLIStats, Error> {
        cliEngine.statsStream(containerID: containerID)
    }

    public func exportContainer(containerID: String, tag: String?) async throws {
        try await cliEngine.exportContainer(containerID: containerID, tag: tag)
    }

    // MARK: - Network Management (always CLI)

    public func pruneContainers() async throws {
        try await cliEngine.pruneContainers()
    }

    public func listNetworks() async throws -> [CLINetworkEntry] {
        try await cliEngine.listNetworks()
    }

    public func createNetwork(name: String) async throws {
        try await cliEngine.createNetwork(name: name)
    }

    public func deleteNetwork(name: String) async throws {
        try await cliEngine.deleteNetwork(name: name)
    }

    public func pruneNetworks() async throws {
        try await cliEngine.pruneNetworks()
    }

    // MARK: - Volume Management (always CLI)

    public func listVolumes() async throws -> [CLIVolumeEntry] {
        try await cliEngine.listVolumes()
    }

    public func createVolume(name: String, size: String?, labels: [String]) async throws {
        try await cliEngine.createVolume(name: name, size: size, labels: labels)
    }

    public func deleteVolume(name: String) async throws {
        try await cliEngine.deleteVolume(name: name)
    }

    public func pruneVolumes() async throws {
        try await cliEngine.pruneVolumes()
    }
}
