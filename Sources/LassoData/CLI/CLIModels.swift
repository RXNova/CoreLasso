import Foundation

// MARK: - Runtime Status

/// Mirrors `RuntimeStatus` from apple/container.
///
/// Uses a forgiving `init(from:)` so that unknown future states
/// decode as `.unknown` rather than throwing.
public enum CLIRuntimeStatus: String, Decodable, Sendable {
    case unknown
    case stopped
    case running
    case paused
    case starting
    case stopping

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CLIRuntimeStatus(rawValue: raw) ?? .unknown
    }
}

// MARK: - Container Snapshot
// Matches both `PrintableContainer` (container list --format json)
// and `ContainerSnapshot` (container inspect) from apple/container,
// which share identical JSON keys.

/// Top-level container record returned by `container list --format json`
/// and `container inspect`.
public struct CLIContainerSnapshot: Decodable, Sendable {
    public var status: CLIRuntimeStatus
    public var configuration: CLIContainerConfiguration
    public var networks: [CLINetworkAttachment]
    public var startedDate: Date?
}

/// Mirrors `ContainerConfiguration` — the persistent config stored per container.
public struct CLIContainerConfiguration: Decodable, Sendable {
    public var id: String
    public var image: CLIImageDescription
    public var resources: CLIResources?
    public var platform: CLIPlatform?
    public var publishedPorts: [CLIPublishedPort]?
    public var initProcess: CLIInitProcess?
    public var dns: CLIDnsConfig?
    public var labels: [String: String]?
    public var rosetta: Bool?
    public var ssh: Bool?
    public var mounts: [CLIMount]?
}

/// A single published port from `ContainerConfiguration.publishedPorts`.
public struct CLIPublishedPort: Decodable, Sendable {
    public var hostPort: UInt16
    public var containerPort: UInt16
    public var proto: String
}

/// A mount entry from `ContainerConfiguration.mounts`.
public struct CLIMount: Decodable, Sendable {
    public var source: String?
    public var destination: String
    public var options: [String]?
    public var type: CLIMountType?
}

/// The discriminated union representing the mount type.
public enum CLIMountType: Decodable, Sendable {
    case volume(CLIVolumeMount)
    case bind
    case other

    private enum CodingKeys: String, CodingKey {
        case volume
        case bind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let vm = try? c.decodeIfPresent(CLIVolumeMount.self, forKey: .volume) {
            self = .volume(vm)
        } else if c.contains(.bind) {
            self = .bind
        } else {
            self = .other
        }
    }
}

/// Volume-specific mount metadata.
public struct CLIVolumeMount: Decodable, Sendable {
    public var name: String
    public var format: String?
}

/// The init process configuration (entrypoint + env vars).
public struct CLIInitProcess: Decodable, Sendable {
    public var executable: String?
    public var arguments: [String]?
    public var environment: [String]?
    public var workingDirectory: String?
    public var terminal: Bool?
}

/// DNS configuration from `ContainerConfiguration.dns`.
public struct CLIDnsConfig: Decodable, Sendable {
    public var nameservers: [String]?
    public var searchDomains: [String]?
    public var options: [String]?
}

// MARK: - Stats

/// A single record from `container stats --format json --no-stream`.
public struct CLIStats: Decodable, Sendable {
    public var id: String
    public var cpuUsageUsec: UInt64?
    public var memoryUsageBytes: UInt64?
    public var memoryLimitBytes: UInt64?
    public var networkRxBytes: UInt64?
    public var networkTxBytes: UInt64?
    public var blockReadBytes: UInt64?
    public var blockWriteBytes: UInt64?
    public var numProcesses: Int?
}

// MARK: - Network

/// An entry from `container network list --format json`.
public struct CLINetworkEntry: Decodable, Sendable {
    public var id: String
    public var state: String?
    public struct Config: Decodable, Sendable {
        public var mode: String?
        public var id: String?
    }
    public var config: Config?
    public struct Status: Decodable, Sendable {
        public var ipv4Subnet: String?
        public var ipv6Subnet: String?
        public var ipv4Gateway: String?
    }
    public var status: Status?
}

// MARK: - Volume

/// An entry from `container volume list --format json`.
public struct CLIVolumeEntry: Decodable, Sendable, Equatable {
    public var name: String
    public var sizeInBytes: UInt64?
    public var driver: String?
    public var format: String?
    public var source: String?
    public var createdAt: Double?
    public var labels: [String: String]?
    public var options: [String: String]?

    /// Human-readable size derived from `sizeInBytes`.
    public var formattedSize: String? {
        guard let bytes = sizeInBytes, bytes > 0 else { return nil }
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        if kb >= 1 { return String(format: "%.1f KB", kb) }
        return "\(bytes) B"
    }

    public var createdDate: Date? {
        guard let ts = createdAt else { return nil }
        return Date(timeIntervalSinceReferenceDate: ts)
    }
}

/// Mirrors `ImageDescription` — just the normalized reference string.
public struct CLIImageDescription: Decodable, Sendable {
    /// Full image reference, e.g. `"docker.io/library/ubuntu:latest"`.
    public var reference: String
}

/// CPU and memory resources from `ContainerConfiguration.Resources`.
public struct CLIResources: Decodable, Sendable {
    public var cpus: Int
    public var memoryInBytes: UInt64
}

/// OCI platform descriptor.
public struct CLIPlatform: Decodable, Sendable {
    public var os: String
    public var architecture: String
}

/// A network attachment snapshot.
///
/// `ipv4Address` is a CIDR string (e.g. `"192.168.64.3/24"`).
/// `address` is the legacy key name handled for backwards compat.
public struct CLINetworkAttachment: Decodable, Sendable {
    private var rawIPv4Address: String?

    /// The IPv4 address without prefix length, e.g. `"192.168.64.3"`.
    public var ipAddress: String? {
        rawIPv4Address.map { addr in
            addr.components(separatedBy: "/").first ?? addr
        }
    }

    enum CodingKeys: String, CodingKey {
        case ipv4Address
        case address
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let addr = try? container.decodeIfPresent(String.self, forKey: .ipv4Address) {
            rawIPv4Address = addr
        } else {
            rawIPv4Address = try container.decodeIfPresent(String.self, forKey: .address)
        }
    }
}

// MARK: - Image List
// Matches `PrintableImage` from apple/container's ImageList command.

/// An entry from `container image list --format json`.
public struct CLIImageEntry: Decodable, Sendable {
    /// Normalized image reference, e.g. `"docker.io/library/ubuntu:latest"`.
    public var reference: String
    /// Human-readable total size, e.g. `"80 MB"`.
    public var fullSize: String?
    /// OCI content descriptor containing digest and size.
    public var descriptor: CLIDescriptor?
}

/// Minimal OCI content descriptor.
public struct CLIDescriptor: Decodable, Sendable {
    public var mediaType: String?
    public var digest: String?
    public var size: Int64?
}

// MARK: - Convenience mappings

import LassoCore

extension CLIRuntimeStatus {
    /// Map CLI runtime status to LassoCore's `ContainerState`.
    var containerState: ContainerState {
        switch self {
        case .unknown:   return .error
        case .stopped:   return .stopped
        case .running:   return .running
        case .paused:    return .stopped
        case .starting:  return .starting
        case .stopping:  return .stopping
        }
    }
}

extension CLIContainerSnapshot {
    func toContainerInfo() -> ContainerInfo {
        let cpus = configuration.resources?.cpus ?? 1
        let memory = configuration.resources?.memoryInBytes ?? (512 * 1024 * 1024)

        let portMappings: [PortMapping] = (configuration.publishedPorts ?? []).map {
            PortMapping(hostPort: $0.hostPort, containerPort: $0.containerPort, proto: $0.proto)
        }

        let storage: [StorageSpec] = (configuration.mounts ?? []).map { mount in
            let readOnly = mount.options?.contains("ro") ?? false
            switch mount.type {
            case .volume(let vm):
                return StorageSpec(imagePath: vm.name, containerPath: mount.destination, readOnly: readOnly)
            default:
                return StorageSpec(imagePath: mount.source ?? "", containerPath: mount.destination, readOnly: readOnly)
            }
        }

        let powerProfile = ContainerMetadataStore.shared.powerProfile(for: configuration.id)

        let spec = LassoSpec(
            name: configuration.id,
            image: configuration.image.reference,
            resources: ResourceSpec(cpuCount: cpus, memorySize: memory),
            networking: NetworkSpec(mode: .nat, portMappings: portMappings),
            storage: storage,
            powerProfile: powerProfile,
            environment: configuration.initProcess?.environment ?? [],
            labels: configuration.labels ?? [:],
            rosetta: configuration.rosetta ?? false,
            sshForwarding: configuration.ssh ?? false,
            tty: configuration.initProcess?.terminal ?? false,
            dnsServers: configuration.dns?.nameservers ?? [],
            dnsSearchDomains: configuration.dns?.searchDomains ?? []
        )

        let ipAddress = networks.compactMap(\.ipAddress).first

        return ContainerInfo(
            id: configuration.id,
            spec: spec,
            state: status.containerState,
            createdAt: startedDate,
            startedAt: startedDate,
            ipAddress: ipAddress
        )
    }
}
