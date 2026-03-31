import Foundation

/// A service capable of authenticating with and pulling images from an OCI-compatible container registry.
public protocol RegistryService: Sendable {
    /// Authenticate with a container registry. Returns a bearer token.
    func authenticate(registry: String, repository: String) async throws -> String

    /// Pull an OCI image manifest for the given reference (e.g., "postgres:16-alpine").
    func pullManifest(imageReference: String) async throws -> OCIManifest

    /// Download a specific layer blob to a local path. Returns the local file URL.
    func pullLayer(registry: String, repository: String, digest: String, to destination: URL) async throws -> URL

    /// Pull a full OCI image (manifest + all layers) to a local directory.
    func pullImage(imageReference: String, to destination: URL, onProgress: @Sendable (PullProgress) -> Void) async throws
}
