import SwiftUI
import LassoCore
import LassoData

// MARK: - Data Points

public struct ContainerMemoryStat: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var usedBytes: UInt64
    public var limitBytes: UInt64
    public var percent: Double { limitBytes > 0 ? min(Double(usedBytes) / Double(limitBytes), 1.0) : 0 }
}

public struct ContainerCPUStat: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var percent: Double   // 0–100, normalised per allocated vCPU
}

public struct VolumeSizeStat: Identifiable, Sendable {
    public var id: String { name }
    public var name: String
    public var bytes: UInt64
}

// MARK: - ViewModel

@Observable
@MainActor
public final class OverviewChartsViewModel {

    public var memoryStats: [ContainerMemoryStat] = []
    public var cpuStats: [ContainerCPUStat] = []
    public var volumeStats: [VolumeSizeStat] = []
    public var isLoading = false

    private let engine: any LassoContainerEngine

    public init(engine: any LassoContainerEngine) {
        self.engine = engine
    }

    /// Fetch one-shot stats for all running containers and volume sizes (parallel).
    public func load(
        runningContainers: [ContainerInfo],
        volumes: [CLIVolumeEntry]
    ) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Volume stats — already available, no async needed
        volumeStats = volumes
            .compactMap { vol -> VolumeSizeStat? in
                guard let bytes = vol.sizeInBytes, bytes > 0 else { return nil }
                return VolumeSizeStat(name: vol.name, bytes: bytes)
            }
            .sorted { $0.bytes > $1.bytes }
            .prefix(8)
            .map { $0 }

        guard let svc = engine as? any ContainerStatsService else { return }

        let intervalUsec: Double = 1_000_000  // 1 second

        // Sample 1 — all containers in parallel
        let sample1 = await withTaskGroup(
            of: (ContainerInfo, CLIStats?).self,
            returning: [(ContainerInfo, CLIStats?)].self
        ) { group in
            for container in runningContainers {
                group.addTask { (container, try? await svc.stats(containerID: container.id)) }
            }
            var out: [(ContainerInfo, CLIStats?)] = []
            for await pair in group { out.append(pair) }
            return out
        }

        // Memory from sample 1 (no delta needed)
        memoryStats = sample1
            .compactMap { (container, stat) -> ContainerMemoryStat? in
                guard let used = stat?.memoryUsageBytes, let limit = stat?.memoryLimitBytes, limit > 0 else { return nil }
                return ContainerMemoryStat(id: container.id, name: container.spec.name, usedBytes: used, limitBytes: limit)
            }
            .sorted { $0.percent > $1.percent }

        // Wait 1 second then take sample 2 for CPU delta
        try? await Task.sleep(for: .seconds(1))

        // Sample 2 — all containers in parallel
        let sample2 = await withTaskGroup(
            of: (ContainerInfo, CLIStats?).self,
            returning: [(ContainerInfo, CLIStats?)].self
        ) { group in
            for container in runningContainers {
                group.addTask { (container, try? await svc.stats(containerID: container.id)) }
            }
            var out: [(ContainerInfo, CLIStats?)] = []
            for await pair in group { out.append(pair) }
            return out
        }

        let s1Map = Dictionary(uniqueKeysWithValues: sample1.compactMap { (c, s) in s.map { (c.id, $0) } })

        cpuStats = sample2
            .compactMap { (container, stat2) -> ContainerCPUStat? in
                guard let usec2 = stat2?.cpuUsageUsec,
                      let usec1 = s1Map[container.id]?.cpuUsageUsec,
                      usec2 >= usec1 else { return nil }
                let deltaUsec = Double(usec2 - usec1)
                let cpuCount = max(1, Double(container.spec.resources.cpuCount))
                let pct = min((deltaUsec / intervalUsec) * 100.0 / cpuCount, 100.0)
                return ContainerCPUStat(id: container.id, name: container.spec.name, percent: pct)
            }
            .sorted { $0.percent > $1.percent }
    }
}
