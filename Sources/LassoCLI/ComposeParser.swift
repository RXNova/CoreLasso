import Foundation

// MARK: - Compose model

struct ComposeFile {
    var services: [String: ComposeService]
}

struct ComposeService {
    var image: String?
    var build: ComposeBuild?
    var ports: [String]
    var volumes: [String]
    var environment: [String]
    var name: String?          // set from the service key
    var networks: [String]
    var restart: String?
    var command: String?
    var entrypoint: String?
    var workingDir: String?
    var cpus: Double?
    var memoryMB: Int?
}

struct ComposeBuild {
    var context: String
    var dockerfile: String?
}

// MARK: - Minimal YAML parser

/// Hand-rolled subset YAML parser — handles the docker-compose.yml structure
/// without any external dependencies. Supports:
///   - Nested mappings (indented key: value)
///   - Block sequences (- item)
///   - Quoted and unquoted scalar values
struct ComposeParser {

    enum ParseError: Error, CustomStringConvertible {
        case noServicesBlock
        case malformed(String)
        var description: String {
            switch self {
            case .noServicesBlock: return "No 'services:' block found in compose file"
            case .malformed(let m): return "Parse error: \(m)"
            }
        }
    }

    func parse(fileURL: URL) throws -> ComposeFile {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(text: text)
    }

    func parse(text: String) throws -> ComposeFile {
        let lines = text.components(separatedBy: .newlines)
        let tokens = tokenize(lines)
        return try buildComposeFile(tokens: tokens)
    }

    // MARK: - Tokenization

    private struct Token {
        enum Kind {
            case mapping(key: String, value: String?)  // key: [optional scalar]
            case sequence(value: String)               // - value
        }
        var kind: Kind
        var indent: Int
    }

    private func tokenize(_ lines: [String]) -> [Token] {
        var tokens: [Token] = []
        for raw in lines {
            // Strip comments and blank lines
            let stripped = raw.components(separatedBy: "#").first ?? raw
            guard !stripped.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let indent = stripped.prefix(while: { $0 == " " }).count
            let trimmed = stripped.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- ") {
                let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                tokens.append(Token(kind: .sequence(value: unquote(value)), indent: indent))
            } else if trimmed.hasPrefix("-") && trimmed.count == 1 {
                // bare dash — skip
            } else if trimmed.contains(":") {
                let colonIdx = trimmed.firstIndex(of: ":")!
                let key = String(trimmed[trimmed.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let after = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                let value: String? = after.isEmpty ? nil : unquote(after)
                tokens.append(Token(kind: .mapping(key: key, value: value), indent: indent))
            }
        }
        return tokens
    }

    private func unquote(_ s: String) -> String {
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) ||
           (s.hasPrefix("'")  && s.hasSuffix("'")) {
            return String(s.dropFirst().dropLast())
        }
        return s
    }

    // MARK: - Build model

    private func buildComposeFile(tokens: [Token]) throws -> ComposeFile {
        // Find the top-level 'services:' block
        guard let servicesIdx = tokens.firstIndex(where: {
            if case .mapping(let k, _) = $0.kind { return k == "services" && $0.indent == 0 }
            return false
        }) else { throw ParseError.noServicesBlock }

        let servicesIndent = 2
        var services: [String: ComposeService] = [:]
        var i = servicesIdx + 1

        while i < tokens.count {
            let t = tokens[i]
            guard t.indent == servicesIndent,
                  case .mapping(let svcName, _) = t.kind else {
                if t.indent == 0 { break }  // left services block
                i += 1; continue
            }
            // Collect all tokens that belong to this service (indent > servicesIndent)
            var svcTokens: [Token] = []
            i += 1
            while i < tokens.count && tokens[i].indent > servicesIndent {
                svcTokens.append(tokens[i])
                i += 1
            }
            var svc = parseService(name: svcName, tokens: svcTokens)
            svc.name = svcName
            services[svcName] = svc
        }

        return ComposeFile(services: services)
    }

    private func parseService(name: String, tokens: [Token]) -> ComposeService {
        var svc = ComposeService(
            image: nil, build: nil, ports: [], volumes: [],
            environment: [], name: name, networks: [], restart: nil,
            command: nil, entrypoint: nil, workingDir: nil,
            cpus: nil, memoryMB: nil
        )
        var j = 0
        while j < tokens.count {
            let t = tokens[j]
            guard case .mapping(let key, let val) = t.kind else { j += 1; continue }

            switch key {
            case "image":
                svc.image = val

            case "build":
                if let v = val {
                    svc.build = ComposeBuild(context: v, dockerfile: nil)
                } else {
                    // nested build block
                    var ctx = "."
                    var df: String? = nil
                    j += 1
                    while j < tokens.count && tokens[j].indent > t.indent {
                        if case .mapping(let k2, let v2) = tokens[j].kind {
                            if k2 == "context", let v2 { ctx = v2 }
                            if k2 == "dockerfile", let v2 { df = v2 }
                        }
                        j += 1
                    }
                    svc.build = ComposeBuild(context: ctx, dockerfile: df)
                    continue
                }

            case "ports":
                j += 1
                while j < tokens.count && tokens[j].indent > t.indent {
                    if case .sequence(let v) = tokens[j].kind { svc.ports.append(v) }
                    else if case .mapping(_, let v) = tokens[j].kind, let v { svc.ports.append(v) }
                    j += 1
                }
                continue

            case "volumes":
                j += 1
                while j < tokens.count && tokens[j].indent > t.indent {
                    if case .sequence(let v) = tokens[j].kind { svc.volumes.append(v) }
                    j += 1
                }
                continue

            case "environment":
                j += 1
                while j < tokens.count && tokens[j].indent > t.indent {
                    if case .sequence(let v) = tokens[j].kind {
                        svc.environment.append(v)
                    } else if case .mapping(let k2, let v2) = tokens[j].kind {
                        if let v2 { svc.environment.append("\(k2)=\(v2)") }
                        else      { svc.environment.append(k2) }
                    }
                    j += 1
                }
                continue

            case "networks":
                j += 1
                while j < tokens.count && tokens[j].indent > t.indent {
                    if case .sequence(let v) = tokens[j].kind { svc.networks.append(v) }
                    else if case .mapping(let k2, _) = tokens[j].kind { svc.networks.append(k2) }
                    j += 1
                }
                continue

            case "restart":    svc.restart =    val
            case "command":    svc.command =    val
            case "entrypoint": svc.entrypoint = val
            case "working_dir": svc.workingDir = val
            case "cpus":       svc.cpus =       val.flatMap(Double.init)
            case "mem_limit":
                if let v = val { svc.memoryMB = parseMem(v) }
            default: break
            }
            j += 1
        }
        return svc
    }

    /// Parse docker compose mem_limit strings like "512m", "1g", "2048" (bytes)
    private func parseMem(_ s: String) -> Int? {
        let lower = s.lowercased()
        if lower.hasSuffix("g"), let n = Double(lower.dropLast()) { return Int(n * 1024) }
        if lower.hasSuffix("m"), let n = Double(lower.dropLast()) { return Int(n) }
        if lower.hasSuffix("k"), let n = Double(lower.dropLast()) { return Int(n / 1024) }
        return Int(s)
    }
}
