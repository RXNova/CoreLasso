import Foundation
import LassoCore

/// Errors produced when shelling out to the `container` CLI binary.
public enum CLIError: Error, Sendable {
    /// The `container` binary was not found or is not executable at the given path.
    case binaryNotFound(path: String)
    /// The CLI process exited with a non-zero status code.
    case executionFailed(exitCode: Int32, stderr: String)
    /// The CLI produced output that could not be decoded.
    case outputDecodingFailed
}

// MARK: - LassoEngineError conversion

extension CLIError {
    /// Map a `CLIError` to the corresponding `LassoEngineError`.
    var asEngineError: LassoEngineError {
        switch self {
        case .binaryNotFound(let path):
            return .cliBinaryNotFound(path: path)
        case .executionFailed(let code, let stderr):
            return .cliExecutionFailed(exitCode: code, stderr: stderr)
        case .outputDecodingFailed:
            return .cliOutputDecodingFailed
        }
    }
}

// MARK: - Runner

/// Lightweight async wrapper around the `container` CLI binary.
///
/// All invocations spawn a child `Process`, capture stdout/stderr,
/// and resume on the calling Swift concurrency task.
public struct ContainerCLIRunner: Sendable {

    /// Absolute path to the `container` binary.
    public let binaryPath: String

    public init(binaryPath: String = "/usr/local/bin/container") {
        self.binaryPath = binaryPath
    }

    // MARK: - Execution

    /// Run the CLI with the given arguments and return stdout as a `String`.
    ///
    /// Throws `CLIError.binaryNotFound` if the binary is absent, or
    /// `CLIError.executionFailed` if the process exits non-zero.
    @discardableResult
    public func run(_ args: [String]) async throws -> String {

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = args

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(decoding: stdoutData, as: UTF8.self)
                let stderr = String(decoding: stderrData, as: UTF8.self)

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: stdout)
                } else {
                    continuation.resume(
                        throwing: CLIError.executionFailed(
                            exitCode: proc.terminationStatus,
                            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: CLIError.binaryNotFound(path: binaryPath))
            }
        }
    }

    /// Launch a long-running CLI command and yield each complete newline-delimited
    /// line of stdout as it arrives. The process is terminated automatically when
    /// the caller cancels the enclosing `Task`.
    ///
    /// Useful for `container stats --format json` which streams one JSON array
    /// per line until interrupted.
    public func runLineStream(_ args: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let buffer = LineBuffer()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = args

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                for line in buffer.append(data) {
                    continuation.yield(line)
                }
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let trailing = buffer.flush()
                if !trailing.isEmpty { continuation.yield(trailing) }
                if proc.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(decoding: stderrData, as: UTF8.self)
                    continuation.finish(throwing: CLIError.executionFailed(
                        exitCode: proc.terminationStatus,
                        stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }

            continuation.onTermination = { _ in process.terminate() }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: CLIError.binaryNotFound(path: binaryPath))
            }
        }
    }

    /// Run a CLI command and decode the JSON stdout as `T`.
    public func runJSON<T: Decodable>(_ args: [String]) async throws -> T {
        let output = try await run(args)
        guard let data = output.data(using: .utf8) else {
            throw CLIError.outputDecodingFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CLIError.outputDecodingFailed
        }
    }
}

// MARK: - Line Buffer

/// Thread-safe buffer that accumulates raw bytes and splits on newline boundaries.
/// Used by `runLineStream` to bridge `FileHandle.readabilityHandler` callbacks into
/// the structured concurrency world without data races.
private final class LineBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()
    private static let newline = Data([UInt8(ascii: "\n")])

    func append(_ incoming: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        data.append(incoming)
        var lines: [String] = []
        while let range = data.range(of: Self.newline) {
            let line = String(decoding: data[..<range.lowerBound], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            data = Data(data[range.upperBound...])
            if !line.isEmpty { lines.append(line) }
        }
        return lines
    }

    func flush() -> String {
        lock.lock()
        defer { lock.unlock() }
        let s = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        data.removeAll()
        return s
    }
}
