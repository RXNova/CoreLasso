import SwiftUI
import LassoCore

// MARK: - Volume Mount Entry

/// A single volume or bind-mount row in the Create Container form.
public struct VolumeMountEntry: Identifiable, Sendable {
    public var id = UUID()
    /// Host path (e.g. `/data/pg.img`) or named volume (e.g. `pgdata`).
    public var source: String = ""
    /// Mount point inside the container (e.g. `/var/lib/postgresql`).
    public var target: String = ""
    public var readOnly: Bool = false
}
@Observable
@MainActor
public final class CreateContainerViewModel {

    // MARK: - Form Fields

    public var name = ""
    public var image = ""
    public var cpuCount = 2
    public var memoryMiB = 512
    public var powerProfile: LassoPowerProfile = .balanced
    public var networkMode: NetworkSpec.NetworkMode = .nat
    public var bridgeInterface = ""
    /// Port mappings as "hostPort:containerPort" or "hostPort:containerPort/proto" strings.
    public var portMappingEntries: [String] = []
    /// Volume / bind-mount entries.
    public var volumeMountEntries: [VolumeMountEntry] = []

    // Environment vars as editable "KEY=VALUE" strings
    public var environmentEntries: [String] = []
    // Labels as editable "KEY=VALUE" strings  
    public var labelEntries: [String] = []
    public var dnsServers: [String] = []
    public var dnsSearchDomains: [String] = []
    public var rosetta: Bool = false
    public var sshForwarding: Bool = false
    public var tty: Bool = false
    public var interactive: Bool = false

    // MARK: - State

    public var isCreating = false
    public var errorMessage: String?
    public var availableImages: [ImageInfo] = []

    /// The form is valid when at minimum a name and image are provided.
    public var isValid: Bool { !name.isEmpty && !image.isEmpty }

    // MARK: - Private

    private let engine: any LassoContainerEngine
    /// When non-nil the form is in "edit" mode — recreate replaces this container.
    private let existingContainerID: String?

    // MARK: - Init

    public init(engine: any LassoContainerEngine) {
        self.engine = engine
        self.existingContainerID = nil
    }

    /// Pre-fill the form from an existing container spec for editing.
    public init(editing container: ContainerInfo, engine: any LassoContainerEngine) {
        self.engine = engine
        self.existingContainerID = container.id
        self.name = container.spec.name
        self.image = container.spec.image
        self.cpuCount = container.spec.resources.cpuCount
        self.memoryMiB = max(128, Int(container.spec.resources.memorySize / (1024 * 1024)))
        self.powerProfile = container.spec.powerProfile
        self.networkMode = container.spec.networking.mode
        self.bridgeInterface = container.spec.networking.bridgeInterface ?? ""
        self.portMappingEntries = container.spec.networking.portMappings.map {
            "\($0.hostPort):\($0.containerPort)/\($0.proto)"
        }
        self.environmentEntries = container.spec.environment
        self.labelEntries = container.spec.labels.map { "\($0.key)=\($0.value)" }
        self.dnsServers = container.spec.dnsServers
        self.dnsSearchDomains = container.spec.dnsSearchDomains
        self.rosetta = container.spec.rosetta
        self.sshForwarding = container.spec.sshForwarding
        self.tty = container.spec.tty
        self.interactive = container.spec.interactive
        self.volumeMountEntries = container.spec.storage.map {
            VolumeMountEntry(source: $0.imagePath, target: $0.containerPath ?? "", readOnly: $0.readOnly)
        }
    }

    /// Whether we are editing an existing container.
    public var isEditMode: Bool { existingContainerID != nil }

    /// Load locally available images for the image picker dropdown.
    public func loadAvailableImages() async {
        guard let svc = engine as? any ContainerImageService else { return }
        availableImages = (try? await svc.listImages()) ?? []
    }

    // MARK: - Spec Builder

    /// Assemble form field values into a complete ``LassoSpec``.
    public func buildSpec() -> LassoSpec {
        let resources = ResourceSpec.mib(cpu: cpuCount, memory: memoryMiB)

        let portMappings: [PortMapping] = portMappingEntries
            .filter { !$0.isEmpty }
            .compactMap { entry -> PortMapping? in
                let (portPart, proto) = entry.contains("/")
                    ? (String(entry.split(separator: "/").first ?? ""), String(entry.split(separator: "/").last ?? "tcp"))
                    : (entry, "tcp")
                let parts = portPart.split(separator: ":")
                if parts.count == 2,
                   let host = UInt16(parts[0].trimmingCharacters(in: .whitespaces)),
                   let guest = UInt16(parts[1].trimmingCharacters(in: .whitespaces)) {
                    return PortMapping(hostPort: host, containerPort: guest, proto: proto)
                } else if parts.count == 1, let port = UInt16(parts[0].trimmingCharacters(in: .whitespaces)) {
                    return PortMapping(hostPort: port, containerPort: port, proto: proto)
                }
                return nil
            }

        let networking = NetworkSpec(
            mode: networkMode,
            bridgeInterface: networkMode == .bridged && !bridgeInterface.isEmpty
                ? bridgeInterface
                : nil,
            portMappings: portMappings
        )

        let storageMounts: [StorageSpec] = volumeMountEntries
            .filter { !$0.source.isEmpty }
            .map { entry in
                StorageSpec(
                    imagePath: entry.source,
                    containerPath: entry.target.isEmpty ? nil : entry.target,
                    readOnly: entry.readOnly
                )
            }

        return LassoSpec(
            name: name,
            image: image,
            resources: resources,
            networking: networking,
            storage: storageMounts,
            powerProfile: powerProfile,
            environment: environmentEntries.filter { !$0.isEmpty },
            labels: Dictionary(
                uniqueKeysWithValues: labelEntries
                    .filter { $0.contains("=") }
                    .compactMap { entry -> (String, String)? in
                        let parts = entry.split(separator: "=", maxSplits: 1)
                        guard parts.count == 2 else { return nil }
                        return (String(parts[0]), String(parts[1]))
                    }
            ),
            rosetta: rosetta,
            sshForwarding: sshForwarding,
            tty: tty,
            interactive: interactive,
            dnsServers: dnsServers.filter { !$0.isEmpty },
            dnsSearchDomains: dnsSearchDomains.filter { !$0.isEmpty }
        )
    }

    // MARK: - Actions

    /// In edit mode: stop + delete the old container, then create + start with the new spec.
    /// In create mode: behaves identically to `createContainer()`.
    public func applyChanges() async -> String? {
        guard let oldID = existingContainerID else {
            return await createContainer()
        }

        guard isValid else {
            errorMessage = "Name and image are required."
            return nil
        }

        isCreating = true
        errorMessage = nil

        do {
            // Force-delete handles both running and stopped containers in one step
            try await engine.delete(containerID: oldID)
            // Create and start with new spec
            let spec = buildSpec()
            try await engine.validate(spec: spec)
            let newID = try await engine.create(spec: spec)
            try? await engine.start(containerID: newID)
            isCreating = false
            return newID
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return nil
        }
    }

    /// Validate and create the container. Returns the container ID on success, or `nil` on failure.
    public func createContainer() async -> String? {
        guard isValid else {
            errorMessage = "Name and image are required."
            return nil
        }

        isCreating = true
        errorMessage = nil

        let spec = buildSpec()

        do {
            try await engine.validate(spec: spec)
            let containerID = try await engine.create(spec: spec)
            // Start immediately so the container appears as Running in the list
            try? await engine.start(containerID: containerID)
            isCreating = false
            return containerID
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return nil
        }
    }
}
