import Foundation

/// Errors produced by the OCI registry service during authentication,
/// manifest resolution, and layer downloads.
public enum RegistryError: Error, Sendable {
    case authenticationFailed(registry: String, statusCode: Int)
    case manifestNotFound(imageReference: String)
    case layerDownloadFailed(digest: String, underlying: any Error)
    case invalidImageReference(String)
    case httpError(statusCode: Int, body: String)
}
