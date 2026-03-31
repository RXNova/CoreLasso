import Foundation
import LassoCore

/// Persists per-container metadata that the apple/container CLI cannot store.
///
/// The CLI owns the container runtime state (status, IP, resources) but has
/// no concept of CoreLasso-specific fields like `LassoPowerProfile`. This
/// store bridges that gap by writing a small JSON file alongside the app.
///
/// All methods are thread-safe via a serial dispatch queue.
public final class ContainerMetadataStore: Sendable {

    // MARK: - Shared instance

    public static let shared = ContainerMetadataStore()

    // MARK: - Persisted record

    private struct Record: Codable {
        var powerProfile: String?
    }

    // MARK: - Storage

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.corelasso.metadata-store")

    private init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("CoreLasso", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("container-metadata.json")
    }

    // MARK: - Read

    private func load() -> [String: Record] {
        guard let data = try? Data(contentsOf: fileURL),
              let dict = try? JSONDecoder().decode([String: Record].self, from: data) else {
            return [:]
        }
        return dict
    }

    // MARK: - Write

    private func save(_ dict: [String: Record]) {
        guard let data = try? JSONEncoder().encode(dict) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Public API

    /// Persist the power profile for a container by name.
    public func setPowerProfile(_ profile: LassoPowerProfile, for containerID: String) {
        queue.sync {
            var dict = load()
            var record = dict[containerID] ?? Record()
            record.powerProfile = profile.rawValue
            dict[containerID] = record
            save(dict)
        }
    }

    /// Retrieve the persisted power profile for a container, or `.balanced` if not set.
    public func powerProfile(for containerID: String) -> LassoPowerProfile {
        queue.sync {
            guard let raw = load()[containerID]?.powerProfile,
                  let profile = LassoPowerProfile(rawValue: raw) else {
                return .balanced
            }
            return profile
        }
    }

    /// Remove all metadata for a container (call on delete).
    public func remove(containerID: String) {
        queue.sync {
            var dict = load()
            dict.removeValue(forKey: containerID)
            save(dict)
        }
    }
}
