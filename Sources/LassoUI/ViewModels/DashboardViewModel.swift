import SwiftUI
import LassoCore
import LassoData

/// View model driving the main container dashboard.
///
/// Loads the full container list from the engine, supports search / profile filtering.
@Observable
@MainActor
public final class DashboardViewModel {

    // MARK: - Published State

    public var containers: [ContainerInfo] = []
    public var images: [ImageInfo] = []
    public var networks: [CLINetworkEntry] = []
    public var volumes: [CLIVolumeEntry] = []
    public var isLoading = false
    public var pullingReference: String? = nil
    public var buildingTag: String? = nil
    public var errorMessage: String?
    public var searchText = ""
    public var imageSearchText = ""
    public var engineLabel: String = "container CLI"

    // MARK: - Private

    private let engine: any LassoContainerEngine
    private let imageService: (any ContainerImageService)?
    private var cliEngine: ContainerCLIEngine? { engine as? ContainerCLIEngine }
    private var managementService: (any CLIManagementService)? { engine as? (any CLIManagementService) }

    // MARK: - Init

    public init(engine: any LassoContainerEngine) {
        self.engine = engine
        self.imageService = engine as? any ContainerImageService
    }

    /// Update `engineLabel` from a `HybridContainerEngine` after it resolves its backend.
    public func setEngineLabel(_ label: String) {
        engineLabel = label
    }

    // MARK: - Derived State

    /// Containers filtered by the current search text and optional power-profile filter.
    public var filteredContainers: [ContainerInfo] {
        var result = containers

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.spec.name.lowercased().contains(query) ||
                $0.spec.image.lowercased().contains(query)
            }
        }

        return result
    }

    /// Images filtered by the current image search text.
    public var filteredImages: [ImageInfo] {
        guard !imageSearchText.isEmpty else { return images }
        let q = imageSearchText.lowercased()
        return images.filter { $0.reference.lowercased().contains(q) }
    }

    /// Fetch containers, images, networks, and volumes from the engine.
    public func loadContainers() async {
        isLoading = true
        errorMessage = nil
        async let containerResult = engine.listContainers()
        async let imageResult: [ImageInfo] = {
            guard let svc = imageService else { return [] }
            return (try? await svc.listImages()) ?? []
        }()
        async let networkResult: [CLINetworkEntry] = (try? await managementService?.listNetworks()) ?? []
        async let volumeResult: [CLIVolumeEntry] = (try? await managementService?.listVolumes()) ?? []
        containers = await containerResult
        images = await imageResult
        networks = await networkResult
        volumes = await volumeResult
        isLoading = false
    }

    /// Prune all stopped containers.
    public func pruneContainers() async {
        do {
            try await managementService?.pruneContainers()
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Image Management

    /// Pull an image from any OCI registry by full reference.
    public func pullImage(reference: String) async {
        pullingReference = reference
        do {
            guard let svc = imageService else { return }
            try await svc.pullImage(reference: reference)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
        pullingReference = nil
    }

    /// Build an image from a local Dockerfile/Containerfile context directory.
    public func buildImage(contextPath: String, tag: String, dockerfile: String?) async {
        buildingTag = tag.isEmpty ? contextPath : tag
        do {
            guard let svc = imageService else { return }
            try await svc.buildImage(contextPath: contextPath, tag: tag, dockerfile: dockerfile)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
        buildingTag = nil
    }

    /// Delete a local image. Caller should guard against in-use images.
    public func deleteImage(reference: String) async {
        do {
            guard let svc = imageService else { return }
            try await svc.deleteImage(reference: reference)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns true if any container is currently using this image reference.
    public func imageIsInUse(_ reference: String) -> Bool {
        containers.contains { $0.spec.image == reference }
    }

    /// Returns true if any container has this named volume mounted.
    public func volumeIsInUse(_ name: String) -> Bool {
        containers.contains { container in
            container.spec.storage.contains { !$0.imagePath.hasPrefix("/") && $0.imagePath == name }
        }
    }

    /// Start a container by ID and refresh the list.
    public func startContainer(id: String) async {
        do {
            try await engine.start(containerID: id)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stop a container by ID and refresh the list.
    public func stopContainer(id: String) async {
        do {
            try await engine.stop(containerID: id, timeout: .seconds(10))
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a container by ID and refresh the list.
    public func deleteContainer(id: String) async {
        do {
            try await engine.delete(containerID: id)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Network Management

    /// Create a network and refresh.
    public func createNetwork(name: String) async {
        do {
            try await managementService?.createNetwork(name: name)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a network by name/ID and refresh.
    public func deleteNetwork(name: String) async {
        do {
            try await managementService?.deleteNetwork(name: name)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Prune unused networks and refresh.
    public func pruneNetworks() async {
        do {
            try await managementService?.pruneNetworks()
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Volume Management

    /// Create a volume and refresh.
    public func createVolume(name: String, size: String? = nil, labels: [String] = []) async {
        do {
            try await managementService?.createVolume(name: name, size: size, labels: labels)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a volume by name and refresh.
    public func deleteVolume(name: String) async {
        do {
            try await managementService?.deleteVolume(name: name)
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Prune unused volumes and refresh.
    public func pruneVolumes() async {
        do {
            try await managementService?.pruneVolumes()
            await loadContainers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Subscribe to live state changes for a specific container and update it in-place.
    public func observeContainer(id: String) async {
        do {
            let stream = try await engine.stateStream(for: id)
            for await newState in stream {
                if let index = containers.firstIndex(where: { $0.id == id }) {
                    containers[index].state = newState
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
