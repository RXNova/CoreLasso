import Foundation

/// Errors produced by the container engine during spec parsing, VM configuration, or lifecycle management.
public enum LassoEngineError: LocalizedError, Sendable {
    case specParsingFailed(underlying: any Error)
    case invalidResourceSpec(reason: String)
    case imageNotFound(String)
    case networkConfigurationFailed(reason: String)
    case storageConfigurationFailed(reason: String)
    case vmStartFailed(underlying: any Error)
    case vmStopFailed(underlying: any Error)
    case containerNotFound(id: String)
    case invalidState(current: ContainerState, attempted: String)

    // MARK: - CLI Engine Errors

    /// The `container` CLI binary was not found at the expected path.
    case cliBinaryNotFound(path: String)
    /// The `container` CLI exited with a non-zero status code.
    case cliExecutionFailed(exitCode: Int32, stderr: String)
    /// The CLI produced output that could not be decoded.
    case cliOutputDecodingFailed
}

// MARK: - LocalizedError

extension LassoEngineError {
    public var errorDescription: String? {
        switch self {
        case .specParsingFailed(let e):
            return "Spec parsing failed: \(e.localizedDescription)"
        case .invalidResourceSpec(let reason):
            return "Invalid resource spec: \(reason)"
        case .imageNotFound(let ref):
            return "Image not found: \(ref)"
        case .networkConfigurationFailed(let reason):
            return "Network configuration failed: \(reason)"
        case .storageConfigurationFailed(let reason):
            return "Storage configuration failed: \(reason)"
        case .vmStartFailed(let e):
            return "VM failed to start: \(e.localizedDescription)"
        case .vmStopFailed(let e):
            return "VM failed to stop: \(e.localizedDescription)"
        case .containerNotFound(let id):
            return "Container not found: \(id)"
        case .invalidState(let current, let attempted):
            return "Cannot \(attempted): container is \(current)"
        case .cliBinaryNotFound(let path):
            return "container CLI not found at \(path)"
        case .cliExecutionFailed(let code, let stderr):
            let detail = stderr.isEmpty ? "exit code \(code)" : stderr
            return "container CLI error: \(detail)"
        case .cliOutputDecodingFailed:
            return "Failed to decode container CLI output"
        }
    }
}
