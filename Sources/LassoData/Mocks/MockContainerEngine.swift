import Foundation
import LassoCore

/// A mock container engine for development and SwiftUI previews.
///
/// Stores containers in-memory and simulates lifecycle transitions with
/// brief `Task.sleep` delays. Does not use Virtualization.framework,
/// so it runs without entitlements.
public actor MockContainerEngine: LassoContainerEngine {

    // MARK: - State

    private var containers: [String: ManagedMockContainer] = [:]

    struct ManagedMockContainer {
        let id: String
        let spec: LassoSpec
        var state: ContainerState
        var continuation: AsyncStream<ContainerState>.Continuation?
        let createdAt: Date
        var startedAt: Date?
        var stoppedAt: Date?
        var errorMessage: String?
        var ipAddress: String?
    }

    // MARK: - Init

    public init() {}

    // MARK: - Factory

    /// Creates a mock engine pre-loaded with representative sample containers.
    public static func withSampleData() -> MockContainerEngine {
        MockContainerEngine(prebuiltContainers: buildSampleContainers())
    }

    private init(prebuiltContainers: [String: ManagedMockContainer]) {
        self.containers = prebuiltContainers
    }

    private static func buildSampleContainers() -> [String: ManagedMockContainer] {
        let now = Date()
        let fiveMinutesAgo = now.addingTimeInterval(-300)
        let tenMinutesAgo = now.addingTimeInterval(-600)
        let oneHourAgo = now.addingTimeInterval(-3600)

        let samples: [(String, LassoSpec, ContainerState, Date, Date?, Date?, String?)] = [
            (
                "postgres-db",
                LassoSpec(
                    name: "postgres-db",
                    image: "postgres:16-alpine",
                    resources: .gib(cpu: 4, memory: 2),
                    networking: NetworkSpec(mode: .nat, portMappings: [
                        PortMapping(hostPort: 5432, containerPort: 5432)
                    ]),
                    storage: [StorageSpec(imagePath: "/tmp/corelasso/postgres.img", size: 10 * 1024 * 1024 * 1024)],
                    powerProfile: .performance
                ),
                .running, oneHourAgo, oneHourAgo, nil, "192.168.64.2"
            ),
            (
                "redis-cache",
                LassoSpec(
                    name: "redis-cache",
                    image: "redis:7-alpine",
                    resources: .mib(cpu: 2, memory: 512),
                    networking: NetworkSpec(mode: .nat, portMappings: [
                        PortMapping(hostPort: 6379, containerPort: 6379)
                    ]),
                    storage: [],
                    powerProfile: .utility
                ),
                .running, tenMinutesAgo, tenMinutesAgo, nil, "192.168.64.3"
            ),
            (
                "nginx-proxy",
                LassoSpec(
                    name: "nginx-proxy",
                    image: "nginx:1.25-alpine",
                    resources: .mib(cpu: 2, memory: 256),
                    networking: NetworkSpec(mode: .nat, portMappings: [
                        PortMapping(hostPort: 80, containerPort: 80),
                        PortMapping(hostPort: 443, containerPort: 443)
                    ]),
                    storage: [],
                    powerProfile: .balanced
                ),
                .running, tenMinutesAgo, fiveMinutesAgo, nil, "192.168.64.4"
            ),
            (
                "dev-api",
                LassoSpec(
                    name: "dev-api",
                    image: "node:20-alpine",
                    resources: .gib(cpu: 4, memory: 1),
                    networking: NetworkSpec(mode: .nat, portMappings: [
                        PortMapping(hostPort: 3000, containerPort: 3000),
                        PortMapping(hostPort: 9229, containerPort: 9229)
                    ]),
                    storage: [StorageSpec(imagePath: "/tmp/corelasso/devapi.img", size: 5 * 1024 * 1024 * 1024)],
                    powerProfile: .balanced
                ),
                .stopped, oneHourAgo, oneHourAgo, fiveMinutesAgo, nil
            ),
            (
                "ml-worker",
                LassoSpec(
                    name: "ml-worker",
                    image: "python:3.12-slim",
                    resources: .gib(cpu: 8, memory: 4),
                    networking: NetworkSpec(mode: .nat, portMappings: [
                        PortMapping(hostPort: 8080, containerPort: 8080)
                    ]),
                    storage: [StorageSpec(imagePath: "/tmp/corelasso/mlworker.img", size: 20 * 1024 * 1024 * 1024)],
                    powerProfile: .performance
                ),
                .created, now, nil, nil, nil
            ),
        ]

        var result: [String: ManagedMockContainer] = [:]
        for (id, spec, state, createdAt, startedAt, stoppedAt, ip) in samples {
            result[id] = ManagedMockContainer(
                id: id,
                spec: spec,
                state: state,
                createdAt: createdAt,
                startedAt: startedAt,
                stoppedAt: stoppedAt,
                ipAddress: ip
            )
        }
        return result
    }

    // MARK: - Spec Parsing & Validation

    public func loadSpec(from fileURL: URL) async throws -> LassoSpec {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(LassoSpec.self, from: data)
    }

    public func validate(spec: LassoSpec) async throws {
        guard spec.resources.cpuCount >= 1 else {
            throw LassoEngineError.invalidResourceSpec(reason: "cpuCount must be >= 1")
        }
        guard spec.resources.memorySize >= 128 * 1024 * 1024 else {
            throw LassoEngineError.invalidResourceSpec(reason: "memorySize must be >= 128 MiB")
        }
    }

    // MARK: - Lifecycle

    public func create(spec: LassoSpec) async throws -> String {
        let containerID = UUID().uuidString

        let container = ManagedMockContainer(
            id: containerID,
            spec: spec,
            state: .created,
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
            throw LassoEngineError.invalidState(current: container.state, attempted: "start")
        }

        container.state = .starting
        containers[containerID] = container
        emitState(for: containerID, state: .starting)

        // Simulate VM boot delay
        try await Task.sleep(for: .milliseconds(500))

        container.state = .running
        container.startedAt = Date()
        containers[containerID] = container
        emitState(for: containerID, state: .running)
    }

    public func stop(containerID: String, timeout: Duration) async throws {
        guard var container = containers[containerID] else {
            throw LassoEngineError.containerNotFound(id: containerID)
        }

        guard container.state == .running else {
            throw LassoEngineError.invalidState(current: container.state, attempted: "stop")
        }

        container.state = .stopping
        containers[containerID] = container
        emitState(for: containerID, state: .stopping)

        // Simulate graceful shutdown delay
        try await Task.sleep(for: .milliseconds(300))

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
            throw LassoEngineError.invalidState(current: container.state, attempted: "kill")
        }

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
            throw LassoEngineError.invalidState(current: container.state, attempted: "delete")
        }

        container.state = .deleting
        containers[containerID] = container
        emitState(for: containerID, state: .deleting)

        container.continuation?.yield(.deleted)
        container.continuation?.finish()

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

    // MARK: - Private Helpers

    private func containerInfo(from container: ManagedMockContainer) -> ContainerInfo {
        ContainerInfo(
            id: container.id,
            spec: container.spec,
            state: container.state,
            createdAt: container.createdAt,
            startedAt: container.startedAt,
            stoppedAt: container.stoppedAt,
            errorMessage: container.errorMessage,
            ipAddress: container.ipAddress
        )
    }

    private func emitState(for containerID: String, state: ContainerState) {
        containers[containerID]?.continuation?.yield(state)
    }
}
