import Foundation

/// Virtio block device storage configuration for a container VM.
public struct StorageSpec: Codable, Sendable, Hashable {

    /// Path to the disk image or named volume on the host side.
    /// A path starting with `/` is a bind-mount; otherwise treated as a named volume.
    public var imagePath: String

    /// Mount point inside the container. If nil, defaults to `/mnt/<source-basename>`.
    public var containerPath: String?

    /// Size in bytes for new disk images. Ignored if the image already exists.
    public var size: UInt64?

    /// Filesystem type hint used when formatting new images.
    public var filesystem: Filesystem

    /// Whether the disk is mounted read-only inside the VM.
    public var readOnly: Bool

    public init(imagePath: String, containerPath: String? = nil, size: UInt64? = nil, filesystem: Filesystem = .ext4, readOnly: Bool = false) {
        self.imagePath = imagePath
        self.containerPath = containerPath
        self.size = size
        self.filesystem = filesystem
        self.readOnly = readOnly
    }

    enum CodingKeys: String, CodingKey {
        case imagePath = "image_path"
        case containerPath = "container_path"
        case size
        case filesystem
        case readOnly = "read_only"
    }
}

// MARK: - Filesystem

extension StorageSpec {

    /// Supported filesystem types for Virtio block devices.
    public enum Filesystem: String, Codable, Sendable {
        case ext4
        case apfs
        case raw
    }
}
