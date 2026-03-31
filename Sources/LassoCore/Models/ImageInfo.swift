import Foundation

/// A locally available OCI container image.
public struct ImageInfo: Sendable, Identifiable, Hashable {

    public var id: String { reference }

    /// The fully-qualified image reference, e.g. `"docker.io/library/ubuntu:latest"`.
    public let reference: String

    /// Human-readable size string from the CLI, e.g. `"80 MB"`.
    public let size: String?

    /// OCI content digest, e.g. `"sha256:abc123..."`.
    public let digest: String?

    public init(reference: String, size: String? = nil, digest: String? = nil) {
        self.reference = reference
        self.size = size
        self.digest = digest
    }

    // MARK: - Parsed Helpers

    /// The image name without registry prefix or tag.
    public var name: String {
        let withoutRegistry = reference.components(separatedBy: "/").last ?? reference
        return withoutRegistry.components(separatedBy: ":").first ?? withoutRegistry
    }

    /// The image tag, if one is present in the reference.
    public var tag: String? {
        let withoutRegistry = reference.components(separatedBy: "/").last ?? reference
        let parts = withoutRegistry.components(separatedBy: ":")
        return parts.count >= 2 ? parts.last : nil
    }
}
