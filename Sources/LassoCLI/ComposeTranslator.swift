import Foundation
import LassoData

// MARK: - Compose → container CLI translator

struct ComposeTranslator {

    let binaryPath: String
    let workingDir: URL   // directory containing the compose file

    /// Translate a compose service into the `container run` arguments.
    /// Returns the full argv (without the binary path).
    func runArgs(service: ComposeService, projectName: String) -> [String] {
        let containerName = "\(projectName)_\(service.name ?? "svc")"
        var args: [String] = ["run", "--detach", "--name", containerName]

        // Port mappings  "8080:80" or "80"
        for p in service.ports {
            args += ["-p", p]
        }

        // Volume mounts  "./html:/usr/share/nginx/html:ro" or "pgdata:/var/lib/data"
        for v in service.volumes {
            let resolved = resolveVolumePath(v)
            args += ["-v", resolved]
        }

        // Environment variables
        for e in service.environment {
            args += ["-e", e]
        }

        // Networks
        for n in service.networks {
            args += ["--network", n]
        }

        // Restart — container CLI has no restart flag; note it in a comment (skip)

        // Working dir
        if let wd = service.workingDir {
            args += ["-w", wd]
        }

        // CPU / memory
        if let cpus = service.cpus {
            args += ["-c", String(Int(cpus.rounded(.up)))]
        }
        if let mem = service.memoryMB {
            args += ["-m", "\(mem)MB"]
        }

        // Image (must be last positional)
        if let img = service.image {
            args.append(img)
        }

        // Custom command
        if let cmd = service.command {
            args += cmd.split(separator: " ").map(String.init)
        }

        return args
    }

    /// Translate a compose service `build:` section into `container build` args.
    func buildArgs(service: ComposeService, projectName: String, tag: String) -> [String] {
        guard let build = service.build else { return [] }
        let context = resolveHostPath(build.context)
        var args = ["build", "-t", tag]
        if let df = build.dockerfile {
            args += ["-f", resolveHostPath(df)]
        }
        args.append(context)
        return args
    }

    // MARK: - Helpers

    /// Resolve relative host paths in volume specs against the compose file's directory.
    private func resolveVolumePath(_ spec: String) -> String {
        // spec format: [host:]container[:options]
        var parts = spec.components(separatedBy: ":")
        guard !parts.isEmpty else { return spec }
        let hostOrNamed = parts[0]
        // Named volumes (no path separators) are passed as-is
        if !hostOrNamed.hasPrefix(".") && !hostOrNamed.hasPrefix("/") { return spec }
        parts[0] = resolveHostPath(hostOrNamed)
        return parts.joined(separator: ":")
    }

    private func resolveHostPath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        return workingDir.appendingPathComponent(path).path
    }
}
