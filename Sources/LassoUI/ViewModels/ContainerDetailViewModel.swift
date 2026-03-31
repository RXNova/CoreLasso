import SwiftUI
import LassoCore
import LassoData

@Observable
@MainActor
public final class ContainerDetailViewModel {

    // MARK: - Published State

    public var container: ContainerInfo
    public var isPerformingAction = false
    public var errorMessage: String?
    public var stats: CLIStats?
    /// Volume name → allocated size in bytes, populated externally from the volumes list.
    public var volumeSizes: [String: UInt64] = [:]

    // MARK: - Private

    public let engine: any LassoContainerEngine
    private var statsEngine: (any ContainerStatsService)? { engine as? (any ContainerStatsService) }
    public var canExport: Bool { statsEngine != nil }

    // MARK: - Init

    public init(container: ContainerInfo, engine: any LassoContainerEngine) {
        self.container = container
        self.engine = engine
    }

    // MARK: - Actions

    public func start() async {
        await performAction { try await self.engine.start(containerID: self.container.id) }
    }

    public func stop() async {
        await performAction { try await self.engine.stop(containerID: self.container.id, timeout: .seconds(10)) }
    }

    public func kill() async {
        await performAction { try await self.engine.kill(containerID: self.container.id) }
    }

    public func delete() async {
        await performAction { try await self.engine.delete(containerID: self.container.id) }
    }

    public func export(tag: String?) async {
        guard let svc = statsEngine else { return }
        await performAction {
            try await svc.exportContainer(containerID: self.container.id, tag: tag)
        }
    }

    // MARK: - Stats

    /// Live-streams stats from `container stats --format json`.
    /// Updates `stats` on every CLI tick. Exits cleanly when the Task is cancelled
    /// (view disappears) or the container stops.
    public func startStreaming() async {
        guard container.state == .running, let svc = statsEngine else { stats = nil; return }
        let stream = svc.statsStream(containerID: container.id)
        do {
            for try await fresh in stream {
                guard !Task.isCancelled else { break }
                stats = fresh
            }
        } catch {
            // Stream ended — container stopped or CLI exited. Leave last-known stats visible.
        }
    }

    // MARK: - Refresh / Observe

    public func refresh() async {
        do {
            container = try await engine.info(containerID: container.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func observeState() async {
        do {
            let stream = try await engine.stateStream(for: container.id)
            for await newState in stream {
                container.state = newState
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func performAction(_ action: @Sendable () async throws -> Void) async {
        isPerformingAction = true
        errorMessage = nil
        do {
            try await action()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPerformingAction = false
    }
}
