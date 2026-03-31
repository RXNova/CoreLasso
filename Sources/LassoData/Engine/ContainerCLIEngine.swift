import Foundation
import LassoCore

/// Container engine that delegates all operations to the `container` CLI binary.
///
/// `ContainerCLIEngine` wraps `/usr/local/bin/container` (Apple's open-source
/// container tool) via `ContainerCLIRunner` and implements the full
/// `LassoContainerEngine` lifecycle protocol plus `ContainerImageService`
/// for image management.
///
/// ## Requirements
/// - The `container` system service must be running (`container system start`).
/// - macOS 26 or later (as required by the `container` tool itself).
///
/// ## Container IDs
/// The `container` CLI uses the `--name` value as the container identifier.
/// `create(spec:)` therefore returns `spec.name`.
///
/// ## State streams
/// Because the CLI is stateless, state changes are tracked locally within the
/// actor and emitted eagerly after each lifecycle operation.
public actor ContainerCLIEngine: LassoContainerEngine, ContainerImageService, ContainerStatsService, CLIManagementService {

    // MARK: - Properties

    private let runner: ContainerCLIRunner
    private let parser: LassoSpecParser

    /// Live `AsyncStream` continuations keyed by container ID.
    private var stateContinuations: [String: AsyncStream<ContainerState>.Continuation] = [:]

    /// Last-known state for each container managed in this session.
    private var trackedStates: [String: ContainerState] = [:]

    // MARK: - Init

    /// Create an engine backed by the `container` CLI at `binaryPath`.
    ///
    /// - Parameters:
    ///   - binaryPath: Path to the `container` executable.
    ///     Defaults to `/usr/local/bin/container`.
    ///   - parser: Spec parser; defaults to the standard `LassoSpecParser`.
    public init(
        binaryPath: String = "/usr/local/bin/container",
        parser: LassoSpecParser = LassoSpecParser()
    ) {
        self.runner = ContainerCLIRunner(binaryPath: binaryPath)
        self.parser = parser
    }

    // MARK: - Spec Parsing & Validation

    public func loadSpec(from fileURL: URL) async throws -> LassoSpec {
        try parser.parse(fileURL: fileURL)
    }

    public func validate(spec: LassoSpec) async throws {
        guard FileManager.default.isExecutableFile(atPath: runner.binaryPath) else {
            throw LassoEngineError.cliBinaryNotFound(path: runner.binaryPath)
        }
        guard !spec.image.isEmpty else {
            throw LassoEngineError.imageNotFound(spec.image)
        }
        guard spec.resources.cpuCount >= 1 else {
            throw LassoEngineError.invalidResourceSpec(reason: "cpuCount must be >= 1")
        }
        let minimumMemory: UInt64 = 128 * 1024 * 1024
        guard spec.resources.memorySize >= minimumMemory else {
            throw LassoEngineError.invalidResourceSpec(
                reason: "memorySize \(spec.resources.memorySize) bytes is below the 128 MiB minimum"
            )
        }
    }

    // MARK: - Lifecycle

    /// Create a container from `spec` without starting it.
    ///
    /// Runs: `container create --name <name> -c <cpus> -m <memory> [ports] [volumes] <image>`
    public func create(spec: LassoSpec) async throws -> String {
        var args: [String] = ["create", "--name", spec.name]

        // Resources
        args += ["-c", "\(spec.resources.cpuCount)"]
        let memMiB = spec.resources.memorySize / (1024 * 1024)
        args += ["-m", "\(memMiB)M"]

        // Port mappings
        for port in spec.networking.portMappings {
            args += ["-p", "\(port.hostPort):\(port.containerPort)/\(port.proto)"]
        }

        // Volume / bind-mount storage entries
        for storage in spec.storage {
            let source = storage.imagePath
            let target = storage.containerPath ?? "/mnt/\(URL(fileURLWithPath: source).lastPathComponent)"
            if source.hasPrefix("/") {
                // Bind mount — use -v /host/path:/container/path[:ro]
                var arg = "\(source):\(target)"
                if storage.readOnly { arg += ":ro" }
                args += ["-v", arg]
            } else {
                // Named volume — use --mount type=volume,source=name,target=/path[,readonly]
                var arg = "type=volume,source=\(source),target=\(target)"
                if storage.readOnly { arg += ",readonly" }
                args += ["--mount", arg]
            }
        }

        // Environment variables
        for env in spec.environment {
            args += ["-e", env]
        }

        // Labels
        for (key, value) in spec.labels {
            args += ["-l", "\(key)=\(value)"]
        }

        // DNS
        for dns in spec.dnsServers {
            args += ["--dns", dns]
        }
        for search in spec.dnsSearchDomains {
            args += ["--dns-search", search]
        }

        // Flags
        if spec.rosetta    { args.append("--rosetta") }
        if spec.sshForwarding { args.append("--ssh") }
        if spec.tty        { args.append("-t") }
        if spec.interactive { args.append("-i") }

        // Image (positional — must come last)
        args.append(spec.image)

        do {
            try await runner.run(args)
        } catch let e as CLIError {
            throw e.asEngineError
        }

        updateState(spec.name, to: .created)
        ContainerMetadataStore.shared.setPowerProfile(spec.powerProfile, for: spec.name)
        return spec.name
    }

    /// Start a previously created container.
    ///
    /// Runs: `container start <id>`
    public func start(containerID: String) async throws {
        updateState(containerID, to: .starting)
        do {
            try await runner.run(["start", containerID])
            updateState(containerID, to: .running)
        } catch let e as CLIError {
            updateState(containerID, to: .error)
            throw LassoEngineError.vmStartFailed(underlying: e)
        }
    }

    /// Gracefully stop a running container, sending SIGTERM and waiting `timeout`.
    ///
    /// Runs: `container stop -t <seconds> <id>`
    public func stop(containerID: String, timeout: Duration) async throws {
        updateState(containerID, to: .stopping)
        let seconds = max(1, Int(timeout.components.seconds))
        do {
            try await runner.run(["stop", "-t", "\(seconds)", containerID])
            updateState(containerID, to: .stopped)
        } catch let e as CLIError {
            updateState(containerID, to: .error)
            throw LassoEngineError.vmStopFailed(underlying: e)
        }
    }

    /// Immediately kill a running container with SIGKILL.
    ///
    /// Runs: `container kill <id>`
    public func kill(containerID: String) async throws {
        do {
            try await runner.run(["kill", containerID])
            updateState(containerID, to: .stopped)
        } catch let e as CLIError {
            updateState(containerID, to: .error)
            throw LassoEngineError.vmStopFailed(underlying: e)
        }
    }

    /// Delete a stopped container and finish its state stream.
    ///
    /// Runs: `container delete <id>`
    public func delete(containerID: String) async throws {
        updateState(containerID, to: .deleting)
        do {
            try await runner.run(["delete", "--force", containerID])
        } catch let e as CLIError {
            updateState(containerID, to: .error)
            throw e.asEngineError
        }
        updateState(containerID, to: .deleted)
        ContainerMetadataStore.shared.remove(containerID: containerID)
        stateContinuations[containerID]?.finish()
        stateContinuations.removeValue(forKey: containerID)
        trackedStates.removeValue(forKey: containerID)
    }

    // MARK: - Inspection

    /// Fetch current info for a single container.
    ///
    /// Runs: `container inspect <id>` and parses the JSON array response.
    public func info(containerID: String) async throws -> ContainerInfo {
        let snapshots: [CLIContainerSnapshot]
        do {
            snapshots = try await runner.runJSON(["inspect", containerID])
        } catch let e as CLIError {
            if case .executionFailed = e {
                throw LassoEngineError.containerNotFound(id: containerID)
            }
            throw e.asEngineError
        }
        guard let snapshot = snapshots.first else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }
        return snapshot.toContainerInfo()
    }

    /// List all containers (running and stopped).
    ///
    /// Runs: `container list --all --format json`
    public func listContainers() async -> [ContainerInfo] {
        guard let snapshots: [CLIContainerSnapshot] = try? await runner.runJSON(
            ["list", "--all", "--format", "json"]
        ) else {
            return []
        }
        return snapshots.map { $0.toContainerInfo() }
    }

    // MARK: - State Observation

    /// Returns an `AsyncStream` that emits `ContainerState` values whenever
    /// this engine updates the container's state through a lifecycle operation.
    ///
    /// The stream delivers the current known state immediately and finishes
    /// when the container is deleted.
    public func stateStream(for containerID: String) async throws -> AsyncStream<ContainerState> {
        let (stream, continuation) = AsyncStream<ContainerState>.makeStream()
        // Only yield an initial value when we have a confirmed tracked state.
        // Don't fall back to .created — the caller already has the correct state
        // from listContainers() and a wrong emission would override it.
        if let knownState = trackedStates[containerID] {
            continuation.yield(knownState)
        }
        stateContinuations[containerID] = continuation
        return stream
    }

    // MARK: - Logs

    /// Fetch the last `lines` lines of stdio logs for a container.
    ///
    /// Runs: `container logs -n <lines> <id>`
    ///
    /// - Parameters:
    ///   - containerID: The container name/ID.
    ///   - lines: Number of tail lines to return. Pass `nil` for all logs.
    public func logs(containerID: String, lines: Int? = nil) async throws -> String {
        var args = ["logs"]
        if let n = lines { args += ["-n", "\(n)"] }
        args.append(containerID)
        do {
            return try await runner.run(args)
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Run a command inside a running container and return its output.
    ///
    /// Runs: `container exec <id> <command> [args...]`
    ///
    /// - Parameters:
    ///   - containerID: The container name/ID.
    ///   - command: The command to run, e.g. `["ls", "/tmp"]`.
    public func exec(containerID: String, command: [String]) async throws -> String {
        guard !command.isEmpty else { return "" }
        let args = ["exec", containerID] + command
        do {
            return try await runner.run(args)
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    // MARK: - System

    /// Check whether the `container` system service is running.
    ///
    /// Runs: `container system status --format json`
    public func systemStatus() async throws -> String {
        do {
            return try await runner.run(["system", "status", "--format", "json"])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    // MARK: - ContainerImageService

    /// List all locally cached OCI images.
    ///
    /// Runs: `container image list --format json`
    public func listImages() async throws -> [ImageInfo] {
        let entries: [CLIImageEntry]
        do {
            entries = try await runner.runJSON(["image", "list", "--format", "json"])
        } catch let e as CLIError {
            throw e.asEngineError
        }
        return entries.map {
            ImageInfo(reference: $0.reference, size: $0.fullSize, digest: $0.descriptor?.digest)
        }
    }

    /// Pull an image from a registry.
    ///
    /// Runs: `container image pull <reference>`
    public func pullImage(reference: String) async throws {
        do {
            try await runner.run(["image", "pull", reference])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Push a local image to a registry.
    ///
    /// Runs: `container image push <reference>`
    public func pushImage(reference: String) async throws {
        do {
            try await runner.run(["image", "push", reference])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Delete a local image.
    ///
    /// Runs: `container image delete <reference>`
    public func deleteImage(reference: String) async throws {
        do {
            try await runner.run(["image", "delete", reference])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Apply a new tag to an existing local image.
    ///
    /// Runs: `container image tag <source> <target>`
    public func tagImage(source: String, target: String) async throws {
        do {
            try await runner.run(["image", "tag", source, target])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Build an OCI image from a local Dockerfile / Containerfile.
    ///
    /// Runs: `container build -t <tag> [-f <dockerfile>] <contextPath>`
    public func buildImage(contextPath: String, tag: String, dockerfile: String? = nil) async throws {
        var args = ["build", "-t", tag]
        if let df = dockerfile { args += ["-f", df] }
        args.append(contextPath)
        do {
            try await runner.run(args)
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    // MARK: - Stats

    /// Fetch a single-shot resource snapshot for a container.
    ///
    /// Runs: `container stats --format json --no-stream <id>`
    public func stats(containerID: String) async throws -> CLIStats {
        let results: [CLIStats] = try await runner.runJSON(
            ["stats", "--format", "json", "--no-stream", containerID]
        )
        guard let stat = results.first else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }
        return stat
    }

    /// Continuous stats stream. Runs `container stats --format json <id>` and
    /// yields one `CLIStats` per update tick. The process is killed when the
    /// caller's `Task` is cancelled.
    public nonisolated func statsStream(containerID: String) -> AsyncThrowingStream<CLIStats, Error> {
        let lineStream = runner.runLineStream(["stats", "--format", "json", containerID])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in lineStream {
                        guard let data = line.data(using: .utf8),
                              let results = try? decoder.decode([CLIStats].self, from: data),
                              let stat = results.first else { continue }
                        continuation.yield(stat)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Prune

    /// Remove all stopped containers.
    ///
    /// Runs: `container prune`
    public func pruneContainers() async throws {
        do {
            try await runner.run(["prune"])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    // MARK: - Networks

    /// List all container networks.
    ///
    /// Runs: `container network list --format json`
    public func listNetworks() async throws -> [CLINetworkEntry] {
        do {
            return try await runner.runJSON(["network", "list", "--format", "json"])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Create a new network.
    public func createNetwork(name: String) async throws {
        do {
            try await runner.run(["network", "create", name])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Delete a network.
    public func deleteNetwork(name: String) async throws {
        do {
            try await runner.run(["network", "delete", name])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Remove networks with no container connections.
    public func pruneNetworks() async throws {
        do {
            try await runner.run(["network", "prune"])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    // MARK: - Volumes

    /// List all volumes.
    ///
    /// Runs: `container volume list --format json`
    public func listVolumes() async throws -> [CLIVolumeEntry] {
        do {
            return try await runner.runJSON(["volume", "list", "--format", "json"])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Create a new named volume.
    public func createVolume(name: String, size: String? = nil, labels: [String] = []) async throws {
        var args = ["volume", "create"]
        if let size { args += ["-s", size] }
        for label in labels { args += ["--label", label] }
        args.append(name)
        do {
            try await runner.run(args)
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Delete a volume.
    public func deleteVolume(name: String) async throws {
        do {
            try await runner.run(["volume", "delete", name])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    /// Remove volumes with no container references.
    public func pruneVolumes() async throws {
        do {
            try await runner.run(["volume", "prune"])
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    // MARK: - Export

    /// Export a container's state to an OCI image.
    ///
    /// Runs: `container export [--image <tag>] <id>`
    public func exportContainer(containerID: String, tag: String? = nil) async throws {
        var args = ["export"]
        if let tag { args += ["--image", tag] }
        args.append(containerID)
        do {
            try await runner.run(args)
        } catch let e as CLIError {
            throw e.asEngineError
        }
    }

    // MARK: - Private Helpers

    private func updateState(_ containerID: String, to state: ContainerState) {
        trackedStates[containerID] = state
        stateContinuations[containerID]?.yield(state)
    }
}
