import LassoCore

/// Protocol for engines that support container stats and OCI export.
/// Both `ContainerCLIEngine` and `HybridContainerEngine` conform to this.
public protocol ContainerStatsService: Actor {
    /// Single-shot stats fetch.
    func stats(containerID: String) async throws -> CLIStats
    /// Continuous stats stream — yields one `CLIStats` per CLI update tick
    /// until the task is cancelled or the container stops.
    nonisolated func statsStream(containerID: String) -> AsyncThrowingStream<CLIStats, Error>
    func exportContainer(containerID: String, tag: String?) async throws
}
