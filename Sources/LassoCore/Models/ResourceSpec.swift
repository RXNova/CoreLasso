import Foundation

/// CPU and memory resource constraints for a container VM.
public struct ResourceSpec: Codable, Sendable, Hashable {

    /// Number of virtual CPUs (1...ProcessInfo.processInfo.processorCount).
    public var cpuCount: Int

    /// Memory in bytes.
    public var memorySize: UInt64

    public init(cpuCount: Int, memorySize: UInt64) {
        self.cpuCount = cpuCount
        self.memorySize = memorySize
    }

    enum CodingKeys: String, CodingKey {
        case cpuCount = "cpu_count"
        case memorySize = "memory_size"
    }
}

// MARK: - Convenience Initializers

extension ResourceSpec {

    /// Create a spec with memory specified in MiB.
    public static func mib(cpu: Int, memory: Int) -> ResourceSpec {
        ResourceSpec(cpuCount: cpu, memorySize: UInt64(memory) * 1024 * 1024)
    }

    /// Create a spec with memory specified in GiB.
    public static func gib(cpu: Int, memory: Int) -> ResourceSpec {
        ResourceSpec(cpuCount: cpu, memorySize: UInt64(memory) * 1024 * 1024 * 1024)
    }
}
