import Foundation

enum Shell {
    /// Runs a command to completion and returns its exit status. Output is discarded.
    /// `environment` entries are added to the current environment. With a `timeout`, the command is terminated if it
    /// is still running when the time is up.
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String] = [:],
        timeout: Duration? = nil
    ) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
                return
            }
            if let timeout {
                let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                    if process.isRunning { process.terminate() }
                }
            }
        }
    }

    static func runChecked(_ executable: String, _ arguments: [String]) async throws {
        let status = try await run(executable, arguments)
        guard status == 0 else {
            throw UncorkError.commandFailed(([executable] + arguments).joined(separator: " "), status)
        }
    }
}
