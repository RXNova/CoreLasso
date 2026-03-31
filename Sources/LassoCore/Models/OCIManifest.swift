import Foundation

/// A descriptor pointing to a content-addressable blob in an OCI registry.
public struct OCIDescriptor: Codable, Sendable, Hashable {
    /// MIME type of the referenced content (e.g., "application/vnd.oci.image.layer.v1.tar+gzip").
    public var mediaType: String

    /// Content-addressable digest (e.g., "sha256:abc123...").
    public var digest: String

    /// Size of the referenced content in bytes.
    public var size: Int64

    public init(mediaType: String, digest: String, size: Int64) {
        self.mediaType = mediaType
        self.digest = digest
        self.size = size
    }

    enum CodingKeys: String, CodingKey {
        case mediaType
        case digest
        case size
    }
}

/// An OCI image manifest describing the config and layer blobs that compose an image.
public struct OCIManifest: Codable, Sendable, Hashable {
    /// Manifest schema version (typically 2).
    public var schemaVersion: Int

    /// MIME type of the manifest itself.
    public var mediaType: String

    /// Descriptor for the image configuration blob.
    public var config: OCIDescriptor

    /// Ordered list of layer descriptors that compose the filesystem.
    public var layers: [OCIDescriptor]

    public init(schemaVersion: Int, mediaType: String, config: OCIDescriptor, layers: [OCIDescriptor]) {
        self.schemaVersion = schemaVersion
        self.mediaType = mediaType
        self.config = config
        self.layers = layers
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case mediaType
        case config
        case layers
    }
}
