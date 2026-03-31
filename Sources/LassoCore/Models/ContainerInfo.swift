import Foundation

/// Snapshot of a container's current status, suitable for UI display.
public struct ContainerInfo: Sendable, Identifiable, Equatable {

    /// Unique container identifier assigned by the engine.
    public let id: String

    /// The spec this container was created from.
    public let spec: LassoSpec

    /// Current lifecycle state.
    public var state: ContainerState

    /// When the container was created (or first started, for CLI containers).
    public var createdAt: Date?

    /// When the container was last started. `nil` if never started.
    public var startedAt: Date?

    /// When the container was last stopped. `nil` if still running or never started.
    public var stoppedAt: Date?

    /// Error description if `state` is `.error`.
    public var errorMessage: String?

    /// VM process ID when running.
    public var pid: Int32?

    /// IP address assigned to the VM's virtual NIC. `nil` if not yet assigned.
    public var ipAddress: String?

    public init(
        id: String,
        spec: LassoSpec,
        state: ContainerState,
        createdAt: Date? = nil,
        startedAt: Date? = nil,
        stoppedAt: Date? = nil,
        errorMessage: String? = nil,
        pid: Int32? = nil,
        ipAddress: String? = nil
    ) {
        self.id = id
        self.spec = spec
        self.state = state
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.errorMessage = errorMessage
        self.pid = pid
        self.ipAddress = ipAddress
    }
}
