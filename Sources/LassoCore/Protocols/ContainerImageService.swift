import Foundation

/// Provides OCI image management backed by the `container` CLI.
///
/// `ContainerCLIEngine` conforms to this protocol so that view-model
/// and UI layers can pull/push/list/delete images without coupling to
/// the specific engine implementation.
public protocol ContainerImageService: Sendable {

    /// List all locally cached OCI images.
    func listImages() async throws -> [ImageInfo]

    /// Pull an image from a registry by reference, e.g. `"ubuntu:latest"`.
    func pullImage(reference: String) async throws

    /// Push a local image to a registry.
    func pushImage(reference: String) async throws

    /// Delete a local image by reference.
    func deleteImage(reference: String) async throws

    /// Tag an existing image with a new reference.
    func tagImage(source: String, target: String) async throws

    /// Build an OCI image from a local build context directory.
    ///
    /// - Parameters:
    ///   - contextPath: Path to the directory containing the `Dockerfile`.
    ///   - tag: Name and optional tag for the produced image.
    ///   - dockerfile: Override the default `Dockerfile` path within the context.
    func buildImage(contextPath: String, tag: String, dockerfile: String?) async throws
}
