import Foundation

enum Shell {
    /// Runs a command to completion and returns its exit status. Output is discarded.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
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
