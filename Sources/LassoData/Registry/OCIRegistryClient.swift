import Foundation
import LassoCore

/// Concrete OCI registry client that speaks the Docker Registry HTTP API V2.
///
/// Uses `URLSession` for all network operations and supports token-based
/// authentication against Docker Hub and other OCI-compliant registries.
public actor OCIRegistryClient: RegistryService {

    // MARK: - Properties

    private let session: URLSession

    /// In-memory cache of bearer tokens keyed by "registry/repository".
    private var tokenCache: [String: String] = [:]

    // MARK: - Constants

    private static let dockerAuthURL = "https://auth.docker.io/token"
    private static let dockerService = "registry.docker.io"

    /// Media types we accept when pulling manifests.
    private static let manifestAcceptHeaders: [String] = [
        "application/vnd.oci.image.manifest.v1+json",
        "application/vnd.docker.distribution.manifest.v2+json",
        "application/vnd.oci.image.index.v1+json",
        "application/vnd.docker.distribution.manifest.list.v2+json",
    ]

    // MARK: - Initialization

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - RegistryService

    public func authenticate(registry: String, repository: String) async throws -> String {
        let cacheKey = "\(registry)/\(repository)"
        if let cached = tokenCache[cacheKey] {
            return cached
        }

        let token: String
        if registry == "registry-1.docker.io" {
            token = try await authenticateDockerHub(repository: repository)
        } else {
            token = try await authenticateGeneric(registry: registry, repository: repository)
        }

        tokenCache[cacheKey] = token
        return token
    }

    public func pullManifest(imageReference: String) async throws -> OCIManifest {
        let ref = try ImageReference(parsing: imageReference)
        let token = try await authenticate(registry: ref.registry, repository: ref.repository)

        let urlString = "https://\(ref.registry)/v2/\(ref.repository)/manifests/\(ref.reference)"
        guard let url = URL(string: urlString) else {
            throw RegistryError.invalidImageReference(imageReference)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.manifestAcceptHeaders.joined(separator: ", "), forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistryError.httpError(statusCode: 0, body: "Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw RegistryError.authenticationFailed(registry: ref.registry, statusCode: 401)
        case 404:
            throw RegistryError.manifestNotFound(imageReference: imageReference)
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RegistryError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        // The response might be a manifest list / index. For now we decode as a single manifest.
        // A future enhancement can resolve multi-arch manifests.
        let manifest = try JSONDecoder().decode(OCIManifest.self, from: data)
        return manifest
    }

    public func pullLayer(
        registry: String,
        repository: String,
        digest: String,
        to destination: URL
    ) async throws -> URL {
        let token = try await authenticate(registry: registry, repository: repository)

        let urlString = "https://\(registry)/v2/\(repository)/blobs/\(digest)"
        guard let url = URL(string: urlString) else {
            throw RegistryError.invalidImageReference("\(registry)/\(repository)@\(digest)")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (tempURL, response) = try await session.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RegistryError.httpError(statusCode: 0, body: "Invalid response type")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let body: String
                if let data = try? Data(contentsOf: tempURL) {
                    body = String(data: data, encoding: .utf8) ?? ""
                } else {
                    body = ""
                }
                throw RegistryError.httpError(statusCode: httpResponse.statusCode, body: body)
            }

            // Derive a filename from the digest (e.g., "sha256_abc123.tar.gz").
            let safeDigest = digest.replacingOccurrences(of: ":", with: "_")
            let layerURL = destination.appendingPathComponent(safeDigest)

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: layerURL.path) {
                try fileManager.removeItem(at: layerURL)
            }
            try fileManager.moveItem(at: tempURL, to: layerURL)

            return layerURL
        } catch let error as RegistryError {
            throw error
        } catch {
            throw RegistryError.layerDownloadFailed(digest: digest, underlying: error)
        }
    }

    public func pullImage(
        imageReference: String,
        to destination: URL,
        onProgress: @Sendable (PullProgress) -> Void
    ) async throws {
        let manifest = try await pullManifest(imageReference: imageReference)
        let ref = try ImageReference(parsing: imageReference)

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destination.path) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        // Save manifest to disk.
        let manifestData = try JSONEncoder().encode(manifest)
        let manifestURL = destination.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestURL)

        // Download config blob.
        _ = try await pullLayer(
            registry: ref.registry,
            repository: ref.repository,
            digest: manifest.config.digest,
            to: destination
        )

        // Download each layer.
        let totalLayers = manifest.layers.count
        for (index, layer) in manifest.layers.enumerated() {
            // Report initial progress for this layer.
            onProgress(PullProgress(
                layerDigest: layer.digest,
                bytesDownloaded: 0,
                totalBytes: layer.size,
                layerIndex: index,
                totalLayers: totalLayers
            ))

            _ = try await pullLayer(
                registry: ref.registry,
                repository: ref.repository,
                digest: layer.digest,
                to: destination
            )

            // Report completion of this layer.
            onProgress(PullProgress(
                layerDigest: layer.digest,
                bytesDownloaded: layer.size,
                totalBytes: layer.size,
                layerIndex: index,
                totalLayers: totalLayers
            ))
        }
    }

    // MARK: - Private Auth Helpers

    /// Authenticates against Docker Hub's token service.
    private func authenticateDockerHub(repository: String) async throws -> String {
        var components = URLComponents(string: Self.dockerAuthURL)!
        components.queryItems = [
            URLQueryItem(name: "service", value: Self.dockerService),
            URLQueryItem(name: "scope", value: "repository:\(repository):pull"),
        ]

        guard let url = components.url else {
            throw RegistryError.authenticationFailed(registry: "registry-1.docker.io", statusCode: 0)
        }

        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RegistryError.authenticationFailed(registry: "registry-1.docker.io", statusCode: 0)
        }

        guard httpResponse.statusCode == 200 else {
            throw RegistryError.authenticationFailed(
                registry: "registry-1.docker.io",
                statusCode: httpResponse.statusCode
            )
        }

        let tokenResponse = try JSONDecoder().decode(DockerTokenResponse.self, from: data)
        return tokenResponse.token
    }

    /// Attempts bearer-token authentication against a generic OCI registry
    /// by parsing the `Www-Authenticate` challenge from a 401 response.
    private func authenticateGeneric(registry: String, repository: String) async throws -> String {
        // First, probe the registry to get a 401 with a Www-Authenticate header.
        let probeURLString = "https://\(registry)/v2/"
        guard let probeURL = URL(string: probeURLString) else {
            throw RegistryError.authenticationFailed(registry: registry, statusCode: 0)
        }

        let (_, probeResponse) = try await session.data(for: URLRequest(url: probeURL))

        guard let httpProbe = probeResponse as? HTTPURLResponse else {
            throw RegistryError.authenticationFailed(registry: registry, statusCode: 0)
        }

        // If the registry doesn't require auth, return an empty token.
        if httpProbe.statusCode == 200 {
            return ""
        }

        guard httpProbe.statusCode == 401,
              let challenge = httpProbe.value(forHTTPHeaderField: "Www-Authenticate") ?? httpProbe.value(forHTTPHeaderField: "WWW-Authenticate")
        else {
            throw RegistryError.authenticationFailed(registry: registry, statusCode: httpProbe.statusCode)
        }

        // Parse Bearer realm="...",service="...",scope="..."
        let params = parseBearerChallenge(challenge)
        guard let realm = params["realm"] else {
            throw RegistryError.authenticationFailed(registry: registry, statusCode: 401)
        }

        var components = URLComponents(string: realm)!
        var queryItems = components.queryItems ?? []
        if let service = params["service"] {
            queryItems.append(URLQueryItem(name: "service", value: service))
        }
        queryItems.append(URLQueryItem(name: "scope", value: "repository:\(repository):pull"))
        components.queryItems = queryItems

        guard let tokenURL = components.url else {
            throw RegistryError.authenticationFailed(registry: registry, statusCode: 0)
        }

        let (data, response) = try await session.data(for: URLRequest(url: tokenURL))

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (probeResponse as? HTTPURLResponse)?.statusCode ?? 0
            throw RegistryError.authenticationFailed(registry: registry, statusCode: statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(DockerTokenResponse.self, from: data)
        return tokenResponse.token
    }

    /// Parses a Bearer challenge header into key-value pairs.
    /// Input: `Bearer realm="https://...",service="ghcr.io",scope="repository:foo:pull"`
    private func parseBearerChallenge(_ header: String) -> [String: String] {
        var result: [String: String] = [:]

        // Strip "Bearer " prefix
        let body: String
        if header.lowercased().hasPrefix("bearer ") {
            body = String(header.dropFirst("Bearer ".count))
        } else {
            body = header
        }

        // Simple state machine to parse key="value" pairs separated by commas.
        let pairs = body.split(separator: ",")
        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            guard let equalsIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes.
            if value.hasPrefix("\"") && value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }

        return result
    }
}

// MARK: - Internal Response Types

/// Token response from Docker Hub or compatible token services.
private struct DockerTokenResponse: Codable, Sendable {
    let token: String
    let accessToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case token
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}
