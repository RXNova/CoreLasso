import Foundation
import LassoData

// MARK: - Shell helpers

@discardableResult
func shell(_ args: [String], streaming: Bool = false) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/container")
    process.arguments = args
    if streaming {
        process.standardOutput = FileHandle.standardOutput
        process.standardError  = FileHandle.standardError
    }
    try? process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

func printStep(_ msg: String)    { print("\u{001B}[34m==> \u{001B}[0m\(msg)") }
func printSuccess(_ msg: String) { print("\u{001B}[32m✔  \u{001B}[0m\(msg)") }
func printError(_ msg: String)   { fputs("\u{001B}[31m✖  \u{001B}[0m\(msg)\n", stderr) }
func printWarn(_ msg: String)    { print("\u{001B}[33m⚠  \u{001B}[0m\(msg)") }

func stopBuilder() {
    printStep("Stopping builder VM…")
    shell(["builder", "stop"])
    printSuccess("Builder VM stopped")
}

// MARK: - Lasso CLI commands

struct LassoCLI {

    static func run(_ argv: [String]) {
        guard argv.count >= 2 else { printHelp(); exit(0) }
        let cmd = argv[1]
        let rest = Array(argv.dropFirst(2))
        switch cmd {
        case "up":      up(args: rest)
        case "down":    down(args: rest)
        case "build":   buildCmd(args: rest)
        case "ps":      psCmd()
        case "--help", "-h", "help": printHelp()
        default:
            printError("Unknown command '\(cmd)'. Run 'lasso --help' for usage.")
            exit(1)
        }
    }

    // MARK: - lasso up

    /// Parse and start all services from a docker-compose.yml (or Dockerfile).
    static func up(args: [String]) {
        var filePath: String? = nil
        var projectName: String = "lasso"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "-f", "--file":
                i += 1; filePath = i < args.count ? args[i] : nil
            case "-p", "--project":
                i += 1; projectName = i < args.count ? args[i] : projectName
            default: break
            }
            i += 1
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // Dockerfile shortcut: lasso up --dockerfile [context]
        if let f = filePath, f.lowercased().contains("dockerfile") {
            let contextDir = args.last.map { URL(fileURLWithPath: $0, relativeTo: cwd).path } ?? cwd.path
            let tag = "\(projectName):lasso"
            printStep("Building image from Dockerfile as \(tag)")
            let code = shell(["build", "-t", tag, "--file", f, contextDir], streaming: true)
            guard code == 0 else { printError("Build failed"); exit(1) }
            stopBuilder()
            printStep("Running container '\(projectName)'")
            shell(["run", "--detach", "--name", projectName, tag], streaming: true)
            printSuccess("Container '\(projectName)' started")
            return
        }

        // Compose file
        let composeURL: URL
        if let f = filePath {
            composeURL = URL(fileURLWithPath: f, relativeTo: cwd).standardized
        } else {
            // Auto-detect
            let candidates = ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"]
            guard let found = candidates.first(where: {
                FileManager.default.fileExists(atPath: cwd.appendingPathComponent($0).path)
            }) else {
                printError("No compose file found. Use -f <file> or run from a directory containing docker-compose.yml")
                exit(1)
            }
            composeURL = cwd.appendingPathComponent(found)
        }

        printStep("Reading \(composeURL.lastPathComponent)")
        let compose: ComposeFile
        do {
            compose = try ComposeParser().parse(fileURL: composeURL)
        } catch {
            printError("Failed to parse compose file: \(error)")
            exit(1)
        }

        let translator = ComposeTranslator(
            binaryPath: "/usr/local/bin/container",
            workingDir: composeURL.deletingLastPathComponent()
        )

        for (name, service) in compose.services.sorted(by: { $0.key < $1.key }) {
            var svc = service
            svc.name = name

            // Build if needed
            if let build = svc.build, svc.image == nil {
                let tag = "\(projectName)_\(name):latest"
                svc = ComposeService(
                    image: tag, build: build, ports: svc.ports, volumes: svc.volumes,
                    environment: svc.environment, name: name, networks: svc.networks,
                    restart: svc.restart, command: svc.command, entrypoint: svc.entrypoint,
                    workingDir: svc.workingDir, cpus: svc.cpus, memoryMB: svc.memoryMB
                )
                printStep("Building service '\(name)' → \(tag)")
                let buildArgs = translator.buildArgs(service: svc, projectName: projectName, tag: tag)
                let code = shell(buildArgs, streaming: true)
                guard code == 0 else { printError("Build failed for service '\(name)'"); exit(1) }
                stopBuilder()
            }

            guard svc.image != nil else {
                printWarn("Service '\(name)' has no image or build — skipping")
                continue
            }

            let runArgs = translator.runArgs(service: svc, projectName: projectName)
            let containerName = "\(projectName)_\(name)"
            printStep("Starting '\(containerName)'")
            let code = shell(runArgs, streaming: true)
            if code == 0 {
                printSuccess("'\(containerName)' started")
            } else {
                printError("Failed to start '\(containerName)'")
            }
        }
    }

    // MARK: - lasso down

    static func down(args: [String]) {
        var filePath: String? = nil
        var projectName: String = "lasso"
        var i = 0
        while i < args.count {
            switch args[i] {
            case "-f", "--file":
                i += 1; filePath = i < args.count ? args[i] : nil
            case "-p", "--project":
                i += 1; projectName = i < args.count ? args[i] : projectName
            default: break
            }
            i += 1
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let composeURL: URL
        if let f = filePath {
            composeURL = URL(fileURLWithPath: f, relativeTo: cwd).standardized
        } else {
            let candidates = ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"]
            guard let found = candidates.first(where: {
                FileManager.default.fileExists(atPath: cwd.appendingPathComponent($0).path)
            }) else {
                printError("No compose file found.")
                exit(1)
            }
            composeURL = cwd.appendingPathComponent(found)
        }

        let compose: ComposeFile
        do {
            compose = try ComposeParser().parse(fileURL: composeURL)
        } catch {
            printError("Failed to parse compose file: \(error)")
            exit(1)
        }

        for name in compose.services.keys.sorted() {
            let containerName = "\(projectName)_\(name)"
            printStep("Stopping '\(containerName)'")
            shell(["stop", containerName], streaming: true)
            printStep("Removing '\(containerName)'")
            let code = shell(["delete", containerName], streaming: true)
            if code == 0 { printSuccess("'\(containerName)' removed") }
        }
    }

    // MARK: - lasso build

    static func buildCmd(args: [String]) {
        var contextPath = "."
        var tag: String? = nil
        var dockerfilePath: String? = nil
        var i = 0
        while i < args.count {
            switch args[i] {
            case "-t", "--tag":
                i += 1; tag = i < args.count ? args[i] : nil
            case "-f", "--file":
                i += 1; dockerfilePath = i < args.count ? args[i] : nil
            default:
                contextPath = args[i]
            }
            i += 1
        }

        let resolvedTag = tag ?? "lasso-build:latest"
        var buildArgs = ["build", "-t", resolvedTag]
        if let df = dockerfilePath { buildArgs += ["-f", df] }
        buildArgs.append(contextPath)

        printStep("Building image '\(resolvedTag)' from \(contextPath)")
        let code = shell(buildArgs, streaming: true)
        if code == 0 {
            stopBuilder()
            printSuccess("Built '\(resolvedTag)'")
        } else { printError("Build failed"); exit(1) }
    }

    // MARK: - lasso ps

    static func psCmd() {
        shell(["list", "--format", "json"], streaming: true)
    }

    // MARK: - Help

    static func printHelp() {
        print("""
        \u{001B}[1mlasso\u{001B}[0m — CoreLasso CLI

        USAGE:
          lasso <command> [options]

        COMMANDS:
          up      [-f compose.yml] [-p project]   Start services from a compose file
          down    [-f compose.yml] [-p project]   Stop and remove compose services
          build   [-f Dockerfile] [-t tag] [ctx]  Build an image from a Dockerfile
          ps                                      List running containers
          help                                    Show this help

        EXAMPLES:
          lasso up                                # reads docker-compose.yml in cwd
          lasso up -f myapp/docker-compose.yml -p myapp
          lasso up -f Dockerfile                  # single container from Dockerfile
          lasso down -p myapp
          lasso build -t my-nginx:latest ./nginx-sample
          lasso build -f Dockerfile -t app:dev .
        """)
    }
}
