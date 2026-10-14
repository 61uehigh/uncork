import Foundation

/// Starts Windows programs under Wine.
public struct Launcher: Sendable {
    public static let supportedExtensions: Set<String> = ["exe", "msi"]

    public let runtime: WineRuntime
    public let prefixes: PrefixManager

    public init(runtime: WineRuntime, prefixes: PrefixManager) {
        self.runtime = runtime
        self.prefixes = prefixes
    }

    public static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Starts `program` and returns without waiting. Wine's output goes to the program's log file.
    /// The first run in a fresh prefix takes longer because Wine sets the prefix up.
    public func launch(_ program: URL, onExit: @escaping @Sendable (Int32) -> Void) throws -> PrefixRecord {
        guard Self.isSupported(program) else { throw UncorkError.unsupportedFile(program.lastPathComponent) }
        let record = try prefixes.recordRun(of: program)

        let log = prefixes.logURL(id: record.id)
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let logHandle = try FileHandle(forWritingTo: log)

        let process = Process()
        process.executableURL = runtime.wineBinary
        process.arguments = program.pathExtension.lowercased() == "msi"
            ? ["msiexec", "/i", program.path]
            : [program.path]
        // Many programs look for their data files next to the .exe.
        process.currentDirectoryURL = program.deletingLastPathComponent()
        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = prefixes.prefixURL(id: record.id).path
        environment["WINEDEBUG"] = "fixme-all"
        process.environment = environment
        process.standardOutput = logHandle
        process.standardError = logHandle
        process.terminationHandler = { finished in
            try? logHandle.close()
            onExit(finished.terminationStatus)
        }
        do {
            try process.run()
        } catch {
            try? logHandle.close()
            throw error
        }
        return record
    }

    /// Stops every Windows program and Wine background service (wineserver, winedevice and friends) in Uncork's
    /// prefixes. Wine leaves those services running after a program exits, so call this when Uncork quits.
    public func stopAll(prefixIDs: [String], timeout: Duration = .seconds(5)) async {
        // First the polite way: `-k` kills each prefix's server and every process attached to it.
        // It fails harmlessly when no server is running for that prefix.
        let wineserver = runtime.wineserverBinary.path
        await withTaskGroup(of: Void.self) { group in
            for id in prefixIDs {
                let prefix = prefixes.prefixURL(id: id).path
                group.addTask {
                    _ = try? await Shell.run(wineserver, ["-k"], environment: ["WINEPREFIX": prefix], timeout: timeout)
                }
            }
        }
        // Services such as winedevice.exe can outlive their server and are then unreachable through it,
        // so sweep up anything still running in an Uncork prefix.
        await WineProcesses.stop(WineProcesses.running(fromRuntimes: prefixes.paths.runtimes, inPrefixes: prefixes.paths.prefixes))
    }
}
