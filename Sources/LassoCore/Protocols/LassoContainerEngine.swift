import Foundation

/// Contract for container VM lifecycle management.
///
/// Implementations are expected to be `actor`s to satisfy `Sendable`
/// and provide data-race safety for VM state. All heavy operations
/// (image pulls, VM boot) are `async` so they can run off the main thread.
public protocol LassoContainerEngine: Sendable {

    // MARK: - Spec Parsing & Validation

    /// Parse and validate a `.lasso` spec from a file URL.
    func loadSpec(from fileURL: URL) async throws -> LassoSpec

    /// Validate a spec against system capabilities (e.g., CPU count <= available cores).
    func validate(spec: LassoSpec) async throws

    // MARK: - Lifecycle

    /// Create a container VM from a validated spec. Returns the assigned container ID.
    func create(spec: LassoSpec) async throws -> String

    /// Start a previously created container.
    func start(containerID: String) async throws

    /// Gracefully stop a running container within the given timeout.
    func stop(containerID: String, timeout: Duration) async throws

    /// Force-kill a running container immediately.
    func kill(containerID: String) async throws

    /// Delete a stopped container and clean up its resources.
    func delete(containerID: String) async throws

    // MARK: - Inspection

    /// Get current info for a specific container.
    func info(containerID: String) async throws -> ContainerInfo

    /// List all managed containers.
    func listContainers() async -> [ContainerInfo]

    // MARK: - State Observation

    /// Stream of state changes for a specific container.
    ///
    /// The MVVM view model layer subscribes to this stream to drive UI updates.
    /// The stream finishes when the container is deleted.
    func stateStream(for containerID: String) async throws -> AsyncStream<ContainerState>
}
