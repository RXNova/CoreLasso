import Foundation

/// A host↔guest port mapping for a container VM.
public struct PortMapping: Codable, Sendable, Hashable {
    /// Port on the host machine.
    public var hostPort: UInt16
    /// Port inside the container VM.
    public var containerPort: UInt16
    /// Protocol: "tcp" or "udp".
    public var proto: String

    public init(hostPort: UInt16, containerPort: UInt16, proto: String = "tcp") {
        self.hostPort = hostPort
        self.containerPort = containerPort
        self.proto = proto
    }

    /// Display string, e.g. "5432/tcp" or "0.0.0.0:5432→5432/tcp"
    public var displayString: String {
        if hostPort == containerPort {
            return "\(containerPort)/\(proto)"
        }
        return "\(hostPort)→\(containerPort)/\(proto)"
    }
}

/// Networking configuration for container VM IP bridging.
public struct NetworkSpec: Codable, Sendable, Hashable {

    /// Networking mode controlling how the VM attaches to the host network.
    public var mode: NetworkMode

    /// Host bridge interface name (e.g., "en0", "bridge100"). Required when `mode` is `.bridged`.
    public var bridgeInterface: String?

    /// MAC address for the VM NIC. `nil` means auto-generated.
    public var macAddress: String?

    /// Exposed port mappings (host port → container port).
    public var portMappings: [PortMapping]

    public init(mode: NetworkMode, bridgeInterface: String? = nil, macAddress: String? = nil, portMappings: [PortMapping] = []) {
        self.mode = mode
        self.bridgeInterface = bridgeInterface
        self.macAddress = macAddress
        self.portMappings = portMappings
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case bridgeInterface = "bridge_interface"
        case macAddress = "mac_address"
        case portMappings = "port_mappings"
    }
}

// MARK: - NetworkMode

extension NetworkSpec {

    /// Determines how the VM's virtual NIC attaches to the host network stack.
    public enum NetworkMode: String, Codable, Sendable {
        /// NAT via `VZNATNetworkDeviceAttachment` — VM shares the host's IP.
        case nat
        /// Bridged via `VZBridgedNetworkDeviceAttachment` — VM gets a dedicated IP on the LAN.
        case bridged
    }
}
