import Foundation

/// Maps container workload intensity to Apple Silicon core affinity via QoS classes.
///
/// - `utility`: Schedules on E-Cores (high-efficiency) — ideal for long-running, battery-friendly workloads.
/// - `balanced`: Mixed scheduling across both core clusters.
/// - `performance`: Prefers P-Cores (high-performance) — for latency-sensitive or compute-heavy workloads.
public enum LassoPowerProfile: String, Codable, Sendable, CaseIterable {
    case utility
    case balanced
    case performance
}

// MARK: - Task Scheduling

extension LassoPowerProfile {

    /// Swift Concurrency `TaskPriority` — use when spawning `Task` or `TaskGroup` children.
    ///
    /// The kernel scheduler uses this to determine core-cluster affinity:
    /// `.utility` → E-Cores, `.medium` → mixed, `.userInitiated` → P-Cores.
    public var taskPriority: TaskPriority {
        switch self {
        case .utility:     .utility
        case .balanced:    .medium
        case .performance: .userInitiated
        }
    }

    /// Human-readable label for UI display.
    public var displayName: String {
        switch self {
        case .utility:     "Efficiency (E-Cores)"
        case .balanced:    "Balanced (Mixed)"
        case .performance: "Performance (P-Cores)"
        }
    }

    /// Short name for compact UI contexts.
    public var shortName: String {
        switch self {
        case .utility:     "Efficiency"
        case .balanced:    "Balanced"
        case .performance: "Performance"
        }
    }

    /// SF Symbol name representing this profile.
    public var symbolName: String {
        switch self {
        case .utility:     "leaf.fill"
        case .balanced:    "circle.lefthalf.filled"
        case .performance: "bolt.fill"
        }
    }
}
