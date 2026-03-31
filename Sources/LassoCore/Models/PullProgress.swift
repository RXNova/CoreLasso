import Foundation

/// Reports download progress for a single layer during an OCI image pull.
public struct PullProgress: Sendable {
    /// The digest of the layer currently being downloaded.
    public var layerDigest: String

    /// Number of bytes downloaded so far for this layer.
    public var bytesDownloaded: Int64

    /// Total size of this layer in bytes.
    public var totalBytes: Int64

    /// Zero-based index of the current layer within the manifest.
    public var layerIndex: Int

    /// Total number of layers in the image.
    public var totalLayers: Int

    /// Overall fraction completed for this layer (0.0 to 1.0).
    public var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }

    public init(layerDigest: String, bytesDownloaded: Int64, totalBytes: Int64, layerIndex: Int, totalLayers: Int) {
        self.layerDigest = layerDigest
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.layerIndex = layerIndex
        self.totalLayers = totalLayers
    }
}
