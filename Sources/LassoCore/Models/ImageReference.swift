import Foundation

/// A parsed OCI image reference such as "postgres:16-alpine" or
/// "ghcr.io/owner/repo@sha256:abc123".
///
/// Applies Docker Hub defaults when no registry or namespace is specified:
/// - Registry defaults to `registry-1.docker.io`
/// - Single-name images (e.g., "postgres") get the `library/` prefix
/// - Tag defaults to `latest` when neither tag nor digest is provided
public struct ImageReference: Sendable, Hashable {

    /// Registry hostname (e.g., "registry-1.docker.io", "ghcr.io").
    public var registry: String

    /// Repository path (e.g., "library/postgres", "owner/myapp").
    public var repository: String

    /// Image tag (e.g., "16-alpine", "latest"). Empty when a digest is used instead.
    public var tag: String

    /// Optional content-addressable digest (e.g., "sha256:abc123...").
    public var digest: String?

    // MARK: - Constants

    private static let defaultRegistry = "registry-1.docker.io"
    private static let defaultTag = "latest"
    private static let libraryPrefix = "library/"

    // MARK: - Initialization

    /// Creates an `ImageReference` by parsing a raw image string.
    ///
    /// Examples of valid input:
    /// - `"postgres"` -> registry-1.docker.io / library/postgres : latest
    /// - `"postgres:16-alpine"` -> registry-1.docker.io / library/postgres : 16-alpine
    /// - `"myuser/myapp:v2"` -> registry-1.docker.io / myuser/myapp : v2
    /// - `"ghcr.io/owner/repo:main"` -> ghcr.io / owner/repo : main
    /// - `"ghcr.io/owner/repo@sha256:abc"` -> ghcr.io / owner/repo @ sha256:abc
    ///
    /// - Parameter string: The raw image reference string.
    /// - Throws: `RegistryError.invalidImageReference` if the string is empty.
    public init(parsing string: String) throws {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw RegistryError.invalidImageReference(string)
        }

        var remaining = trimmed
        var parsedDigest: String?
        var parsedTag: String = Self.defaultTag

        // Extract @digest if present
        if let atIndex = remaining.lastIndex(of: "@") {
            parsedDigest = String(remaining[remaining.index(after: atIndex)...])
            remaining = String(remaining[..<atIndex])
            parsedTag = ""
        }

        // Extract :tag if present (only when no digest)
        if parsedDigest == nil, let colonIndex = remaining.lastIndex(of: ":") {
            let afterColon = String(remaining[remaining.index(after: colonIndex)...])
            // Make sure this colon is not part of a registry port by checking
            // if the part after colon contains a slash (which means it's a registry:port/repo pattern).
            if !afterColon.contains("/") {
                parsedTag = afterColon
                remaining = String(remaining[..<colonIndex])
            }
        }

        // Determine registry vs. repository.
        // A component is treated as a registry hostname if it contains a dot or a colon,
        // or is "localhost".
        let parts = remaining.split(separator: "/", maxSplits: 1).map(String.init)

        let parsedRegistry: String
        let parsedRepository: String

        if parts.count == 1 {
            // Simple name like "postgres"
            parsedRegistry = Self.defaultRegistry
            parsedRepository = Self.libraryPrefix + parts[0]
        } else if Self.looksLikeRegistry(parts[0]) {
            // e.g. "ghcr.io/owner/repo"
            parsedRegistry = parts[0]
            parsedRepository = parts[1]
        } else {
            // e.g. "myuser/myapp" — Docker Hub with explicit namespace
            parsedRegistry = Self.defaultRegistry
            parsedRepository = remaining
        }

        self.registry = parsedRegistry
        self.repository = parsedRepository
        self.tag = parsedTag
        self.digest = parsedDigest
    }

    /// Memberwise initializer for direct construction.
    public init(registry: String, repository: String, tag: String, digest: String? = nil) {
        self.registry = registry
        self.repository = repository
        self.tag = tag
        self.digest = digest
    }

    // MARK: - Helpers

    /// The reference string used for manifest lookup — either the digest or the tag.
    public var reference: String {
        digest ?? tag
    }

    /// Heuristic: a path component looks like a registry hostname if it
    /// contains a dot, a colon (port), or is literally "localhost".
    private static func looksLikeRegistry(_ component: String) -> Bool {
        component.contains(".") || component.contains(":") || component == "localhost"
    }
}
