import Foundation

/// The parsed representation of a `.lasso` configuration file.
public struct LassoSpec: Codable, Sendable, Hashable, Identifiable {

    public var id: String { name }
    public var name: String
    public var image: String
    public var resources: ResourceSpec
    public var networking: NetworkSpec
    public var storage: [StorageSpec]
    public var powerProfile: LassoPowerProfile

    // MARK: - CLI-supported extras

    /// Environment variables passed to the container process (KEY=VALUE or KEY).
    public var environment: [String]
    /// Key-value labels attached to the container.
    public var labels: [String: String]
    /// Enable Rosetta 2 x86 translation inside the container.
    public var rosetta: Bool
    /// Forward the host SSH agent socket into the container.
    public var sshForwarding: Bool
    /// Allocate a TTY for the container process.
    public var tty: Bool
    /// Keep stdin open even when not attached.
    public var interactive: Bool
    /// Custom DNS nameserver IPs.
    public var dnsServers: [String]
    /// DNS search domains.
    public var dnsSearchDomains: [String]

    public init(
        name: String,
        image: String,
        resources: ResourceSpec,
        networking: NetworkSpec,
        storage: [StorageSpec],
        powerProfile: LassoPowerProfile = .balanced,
        environment: [String] = [],
        labels: [String: String] = [:],
        rosetta: Bool = false,
        sshForwarding: Bool = false,
        tty: Bool = false,
        interactive: Bool = false,
        dnsServers: [String] = [],
        dnsSearchDomains: [String] = []
    ) {
        self.name = name
        self.image = image
        self.resources = resources
        self.networking = networking
        self.storage = storage
        self.powerProfile = powerProfile
        self.environment = environment
        self.labels = labels
        self.rosetta = rosetta
        self.sshForwarding = sshForwarding
        self.tty = tty
        self.interactive = interactive
        self.dnsServers = dnsServers
        self.dnsSearchDomains = dnsSearchDomains
    }

    enum CodingKeys: String, CodingKey {
        case name, image, resources, networking, storage
        case powerProfile = "power_profile"
        case environment
        case labels
        case rosetta
        case sshForwarding = "ssh_forwarding"
        case tty
        case interactive
        case dnsServers = "dns_servers"
        case dnsSearchDomains = "dns_search_domains"
    }
}

