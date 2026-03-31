import Foundation

/// Parses `.lasso` configuration files into `LassoSpec` values.
///
/// Currently supports JSON. YAML support can be added later via the Yams library.
public struct LassoSpecParser: Sendable {

    public init() {}

    /// Parse a `LassoSpec` from raw JSON data.
    public func parse(data: Data) throws -> LassoSpec {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(LassoSpec.self, from: data)
        } catch {
            throw LassoEngineError.specParsingFailed(underlying: error)
        }
    }

    /// Parse a `LassoSpec` from a file URL.
    public func parse(fileURL: URL) throws -> LassoSpec {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw LassoEngineError.specParsingFailed(underlying: error)
        }
        return try parse(data: data)
    }
}
