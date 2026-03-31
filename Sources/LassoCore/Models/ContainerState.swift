import Foundation

/// Lifecycle states of a managed container VM.
public enum ContainerState: String, Codable, Sendable {
    case creating
    case created
    case starting
    case running
    case stopping
    case stopped
    case deleting
    case deleted
    case error
}
