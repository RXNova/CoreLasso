import Foundation
@preconcurrency import Virtualization
import LassoCore

/// Concrete container engine backed by Apple's Virtualization.framework.
///
/// Each container maps 1:1 to a `VZVirtualMachine` instance. The actor
/// serialises all mutations to `containers`, while actual VM operations
/// are dispatched to `@MainActor` as required by Virtualization.framework.
public actor VZContainerEngine: LassoContainerEngine {

    // MARK: - Internal Types

    /// Mutable bookkeeping for a single managed container VM.
    struct ManagedContainer {
        let id: String
        let spec: LassoSpec
        var state: ContainerState
        let configuration: VZVirtualMachineConfiguration
        /// Created lazily on `start` — must only be touched on `@MainActor`.
        var vm: VZVirtualMachine?
        /// Drives the per-container `AsyncStream<ContainerState>`.
        var continuation: AsyncStream<ContainerState>.Continuation?
        let createdAt: Date
        var startedAt: Date?
        var stoppedAt: Date?
        var errorMessage: String?
    }

    // MARK: - State

    private var containers: [String: ManagedContainer] = [:]
    private let parser: LassoSpecParser

    // MARK: - Init

    public init(parser: LassoSpecParser = LassoSpecParser()) {
        self.parser = parser
    }

    // MARK: - Spec Parsing & Validation

    public func loadSpec(from fileURL: URL) async throws -> LassoSpec {
        try parser.parse(fileURL: fileURL)
    }

    public func validate(spec: LassoSpec) async throws {
        let hostCPUCount = ProcessInfo.processInfo.processorCount
        let hostMemory = ProcessInfo.processInfo.physicalMemory
        let minimumMemory: UInt64 = 128 * 1024 * 1024 // 128 MiB

        guard spec.resources.cpuCount >= 1,
              spec.resources.cpuCount <= hostCPUCount else {
            throw LassoEngineError.invalidResourceSpec(
                reason: "cpuCount \(spec.resources.cpuCount) must be between 1 and \(hostCPUCount)"
            )
        }

        guard spec.resources.memorySize >= minimumMemory else {
            throw LassoEngineError.invalidResourceSpec(
                reason: "memorySize \(spec.resources.memorySize) bytes is below the 128 MiB minimum"
            )
        }

        guard spec.resources.memorySize <= hostMemory else {
            throw LassoEngineError.invalidResourceSpec(
                reason: "memorySize \(spec.resources.memorySize) exceeds host physical memory \(hostMemory)"
            )
        }
    }

    // MARK: - Lifecycle

    public func create(spec: LassoSpec) async throws -> String {
        let containerID = UUID().uuidString

        let config = try buildConfiguration(for: spec)
        try config.validate()

        let container = ManagedContainer(
            id: containerID,
            spec: spec,
            state: .created,
            configuration: config,
            vm: nil,
            continuation: nil,
            createdAt: Date()
        )

        containers[containerID] = container
        return containerID
    }

    public func start(containerID: String) async throws {
        guard var container = containers[containerID] else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }

        guard container.state == .created || container.state == .stopped else {
            throw LassoEngineError.invalidState(
                current: container.state,
                attempted: "start"
            )
        }

        // Transition to .starting
        container.state = .starting
        containers[containerID] = container
        emitState(for: containerID, state: .starting)

        let config = container.configuration
        let priority = container.spec.powerProfile.taskPriority

        do {
            // VZVirtualMachine must be created and started on the main actor.
            // We use a dedicated Task with the spec's power-profile priority
            // so the kernel scheduler places VM work on the appropriate core cluster.
            let vm = try await Task(priority: priority) { @MainActor in
                let vm = VZVirtualMachine(configuration: config)
                try await vm.start()
                return vm
            }.value

            container.vm = vm
            container.state = .running
            container.startedAt = Date()
            containers[containerID] = container
            emitState(for: containerID, state: .running)
        } catch {
            container.state = .error
            container.errorMessage = error.localizedDescription
            containers[containerID] = container
            emitState(for: containerID, state: .error)
            throw LassoEngineError.vmStartFailed(underlying: error)
        }
    }

    public func stop(containerID: String, timeout: Duration) async throws {
        guard var container = containers[containerID] else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }

        guard container.state == .running else {
            throw LassoEngineError.invalidState(
                current: container.state,
                attempted: "stop"
            )
        }

        container.state = .stopping
        containers[containerID] = container
        emitState(for: containerID, state: .stopping)

        guard let vm = container.vm else {
            throw LassoEngineError.invalidState(current: .stopping, attempted: "stop (no VM)")
        }

        do {
            // Attempt a graceful stop first. requestStop sends an ACPI power-button
            // event to the guest. We then wait for the timeout before force-stopping.
            try await Self.requestGracefulStop(vm: vm)

            // Give the guest time to shut down gracefully.
            try await Task.sleep(for: timeout)

            // Force stop after timeout — in production you would observe
            // VZVirtualMachine.state via KVO and skip this if already stopped.
            try await Self.forceStopVM(vm)
        } catch {
            // Even on error, mark as stopped so the container can be deleted.
            container.state = .error
            container.errorMessage = error.localizedDescription
            containers[containerID] = container
            emitState(for: containerID, state: .error)
            throw LassoEngineError.vmStopFailed(underlying: error)
        }

        container.vm = nil
        container.state = .stopped
        container.stoppedAt = Date()
        containers[containerID] = container
        emitState(for: containerID, state: .stopped)
    }

    public func kill(containerID: String) async throws {
        guard var container = containers[containerID] else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }

        guard container.state == .running || container.state == .stopping else {
            throw LassoEngineError.invalidState(
                current: container.state,
                attempted: "kill"
            )
        }

        guard let vm = container.vm else {
            throw LassoEngineError.invalidState(current: container.state, attempted: "kill (no VM)")
        }

        do {
            try await Self.forceStopVM(vm)
        } catch {
            container.state = .error
            container.errorMessage = error.localizedDescription
            containers[containerID] = container
            emitState(for: containerID, state: .error)
            throw LassoEngineError.vmStopFailed(underlying: error)
        }

        container.vm = nil
        container.state = .stopped
        container.stoppedAt = Date()
        containers[containerID] = container
        emitState(for: containerID, state: .stopped)
    }

    public func delete(containerID: String) async throws {
        guard var container = containers[containerID] else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }

        guard container.state == .created
           || container.state == .stopped
           || container.state == .error else {
            throw LassoEngineError.invalidState(
                current: container.state,
                attempted: "delete"
            )
        }

        container.state = .deleting
        containers[containerID] = container
        emitState(for: containerID, state: .deleting)

        // Finish the observation stream so subscribers see the terminal event.
        container.continuation?.yield(.deleted)
        container.continuation?.finish()
        container.continuation = nil

        containers.removeValue(forKey: containerID)
    }

    // MARK: - Inspection

    public func info(containerID: String) async throws -> ContainerInfo {
        guard let container = containers[containerID] else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }
        return containerInfo(from: container)
    }

    public func listContainers() async -> [ContainerInfo] {
        containers.values.map { containerInfo(from: $0) }
    }

    // MARK: - State Observation

    public func stateStream(for containerID: String) async throws -> AsyncStream<ContainerState> {
        guard var container = containers[containerID] else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }

        let stream = AsyncStream<ContainerState> { continuation in
            container.continuation = continuation
            continuation.yield(container.state)
        }

        containers[containerID] = container
        return stream
    }

    // MARK: - @MainActor VM Helpers

    /// Request a graceful ACPI shutdown if the guest supports it.
    @MainActor
    private static func requestGracefulStop(vm: VZVirtualMachine) throws {
        if vm.canRequestStop {
            try vm.requestStop()
        }
    }

    /// Force-stop the VM. This is the async counterpart used after timeout or for kill.
    @MainActor
    private static func forceStopVM(_ vm: VZVirtualMachine) async throws {
        try await vm.stop()
    }

    // MARK: - Private Helpers

    /// Build a fully-configured `VZVirtualMachineConfiguration` from a spec.
    private func buildConfiguration(for spec: LassoSpec) throws -> VZVirtualMachineConfiguration {
        let config = VZVirtualMachineConfiguration()

        // CPU & Memory
        config.cpuCount = spec.resources.cpuCount
        config.memorySize = spec.resources.memorySize

        // Boot loader — a Linux kernel image would be set here in production.
        // For now the configuration is structurally complete but lacks a bootable kernel.
        // e.g.: config.bootLoader = VZLinuxBootLoader(kernelURL: kernelURL)

        // Storage — one VirtioBlockDevice per StorageSpec entry.
        var storageDevices: [VZStorageDeviceConfiguration] = []
        for storageEntry in spec.storage {
            let imageURL = URL(fileURLWithPath: storageEntry.imagePath)
            let attachment: VZDiskImageStorageDeviceAttachment
            do {
                attachment = try VZDiskImageStorageDeviceAttachment(
                    url: imageURL,
                    readOnly: storageEntry.readOnly
                )
            } catch {
                throw LassoEngineError.storageConfigurationFailed(
                    reason: "Failed to attach disk image at \(storageEntry.imagePath): \(error.localizedDescription)"
                )
            }
            let blockDevice = VZVirtioBlockDeviceConfiguration(attachment: attachment)
            storageDevices.append(blockDevice)
        }
        config.storageDevices = storageDevices

        // Networking
        let networkDevice = VZVirtioNetworkDeviceConfiguration()

        switch spec.networking.mode {
        case .nat:
            networkDevice.attachment = VZNATNetworkDeviceAttachment()

        case .bridged:
            guard let interfaceName = spec.networking.bridgeInterface else {
                throw LassoEngineError.networkConfigurationFailed(
                    reason: "Bridged mode requires a bridge_interface name"
                )
            }
            guard let iface = VZBridgedNetworkInterface.networkInterfaces.first(where: {
                $0.identifier == interfaceName
            }) else {
                throw LassoEngineError.networkConfigurationFailed(
                    reason: "Bridge interface '\(interfaceName)' not found on host"
                )
            }
            networkDevice.attachment = VZBridgedNetworkDeviceAttachment(interface: iface)
        }

        if let macString = spec.networking.macAddress {
            guard let mac = VZMACAddress(string: macString) else {
                throw LassoEngineError.networkConfigurationFailed(
                    reason: "Invalid MAC address: \(macString)"
                )
            }
            networkDevice.macAddress = mac
        } else {
            networkDevice.macAddress = .randomLocallyAdministered()
        }

        config.networkDevices = [networkDevice]

        // Serial console — provides a Virtio console port for guest I/O.
        let consoleDevice = VZVirtioConsoleDeviceConfiguration()
        config.consoleDevices = [consoleDevice]

        // Entropy — provides /dev/random inside the guest.
        let entropyDevice = VZVirtioEntropyDeviceConfiguration()
        config.entropyDevices = [entropyDevice]

        return config
    }

    /// Map internal `ManagedContainer` to the public `ContainerInfo` snapshot.
    private func containerInfo(from container: ManagedContainer) -> ContainerInfo {
        ContainerInfo(
            id: container.id,
            spec: container.spec,
            state: container.state,
            createdAt: container.createdAt,
            startedAt: container.startedAt,
            stoppedAt: container.stoppedAt,
            errorMessage: container.errorMessage
        )
    }

    /// Yield a state change to the container's observation stream, if one is active.
    private func emitState(for containerID: String, state: ContainerState) {
        containers[containerID]?.continuation?.yield(state)
    }
}
