import LassoCore

/// Protocol for engines that expose network and volume management operations.
/// Both `ContainerCLIEngine` and `HybridContainerEngine` conform to this.
public protocol CLIManagementService: Actor {
    func pruneContainers() async throws

    func listNetworks() async throws -> [CLINetworkEntry]
    func createNetwork(name: String) async throws
    func deleteNetwork(name: String) async throws
    func pruneNetworks() async throws

    func listVolumes() async throws -> [CLIVolumeEntry]
    func createVolume(name: String, size: String?, labels: [String]) async throws
    func deleteVolume(name: String) async throws
    func pruneVolumes() async throws
}
