import Foundation

/// Locations Uncork reads and writes. Everything lives under one root so it can be wiped in one go.
public struct UncorkPaths: Sendable {
    public let root: URL

    public init(root: URL = UncorkPaths.defaultRoot) {
        self.root = root
    }

    /// `~/Library/Application Support/Uncork`
    public static var defaultRoot: URL {
        URL.applicationSupportDirectory.appending(path: "Uncork", directoryHint: .isDirectory)
    }

    /// Extracted Wine runtimes, one folder per version.
    public var runtimes: URL { root.appending(path: "Runtime", directoryHint: .isDirectory) }

    /// Points at the active runtime.
    public var runtimeManifest: URL { runtimes.appending(path: "runtime.json") }

    /// One Wine prefix per Windows program.
    public var prefixes: URL { root.appending(path: "Prefixes", directoryHint: .isDirectory) }

    public var logs: URL { root.appending(path: "Logs", directoryHint: .isDirectory) }

    public var downloads: URL { root.appending(path: "Downloads", directoryHint: .isDirectory) }
}
