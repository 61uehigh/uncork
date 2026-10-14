import CryptoKit
import Foundation

/// An installed Wine runtime.
public struct WineRuntime: Codable, Sendable, Equatable {
    public let version: String
    public let wineBinary: URL
}

public enum InstallPhase: Sendable, Equatable {
    case resolving
    /// Fraction in 0...1, or nil when the size is unknown.
    case downloading(Double?)
    case verifying
    case extracting
}

/// Downloads, verifies and unpacks the Wine runtime into Application Support.
public struct RuntimeManager: Sendable {
    public let paths: UncorkPaths

    public init(paths: UncorkPaths = UncorkPaths()) {
        self.paths = paths
    }

    /// The active runtime, or nil if none is installed or its files have gone missing.
    public func installed() -> WineRuntime? {
        guard
            let data = try? Data(contentsOf: paths.runtimeManifest),
            let runtime = try? JSONDecoder().decode(WineRuntime.self, from: data),
            FileManager.default.isExecutableFile(atPath: runtime.wineBinary.path)
        else { return nil }
        return runtime
    }

    public func install(onPhase: @escaping @Sendable (InstallPhase) -> Void) async throws -> WineRuntime {
        let fileManager = FileManager.default
        onPhase(.resolving)
        let asset = try await WineReleaseCatalog.fetchLatest()
        guard let expectedHash = asset.sha256 else { throw UncorkError.missingChecksum(asset.name) }

        try fileManager.createDirectory(at: paths.downloads, withIntermediateDirectories: true)
        let archive = paths.downloads.appending(path: asset.name)
        try? fileManager.removeItem(at: archive)
        onPhase(.downloading(0))
        try await Downloader.download(asset.downloadURL, to: archive) { onPhase(.downloading($0)) }
        defer { try? fileManager.removeItem(at: archive) }

        onPhase(.verifying)
        let actualHash = try Self.sha256(of: archive)
        guard actualHash == expectedHash.lowercased() else {
            throw UncorkError.checksumMismatch(expected: expectedHash, actual: actualHash)
        }

        // Extract next to the final location, then swap it in so a failed install never leaves a half-written runtime.
        onPhase(.extracting)
        try fileManager.createDirectory(at: paths.runtimes, withIntermediateDirectories: true)
        let staging = paths.runtimes.appending(path: ".extract-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }
        try await Shell.runChecked("/usr/bin/tar", ["-xJf", archive.path, "-C", staging.path])

        let destination = paths.runtimes.appending(path: asset.version, directoryHint: .isDirectory)
        try? fileManager.removeItem(at: destination)
        try fileManager.moveItem(at: staging, to: destination)

        guard let wineBinary = Self.findWineBinary(in: destination) else { throw UncorkError.wineBinaryNotFound }
        let runtime = WineRuntime(version: asset.version, wineBinary: wineBinary)
        try JSONEncoder().encode(runtime).write(to: paths.runtimeManifest, options: .atomic)
        return runtime
    }

    /// Finds `<Something>.app/Contents/Resources/wine/bin/wine` inside an extracted archive.
    static func findWineBinary(in directory: URL) -> URL? {
        let apps = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for app in apps where app.pathExtension == "app" {
            let binary = app.appending(path: "Contents/Resources/wine/bin/wine")
            if FileManager.default.isExecutableFile(atPath: binary.path) { return binary }
        }
        return nil
    }

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// URLSession's async download API reports no progress, so this wraps the delegate-based one.
private final class Downloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let onProgress: @Sendable (Double?) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var moveError: Error?

    private init(destination: URL, onProgress: @escaping @Sendable (Double?) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
    }

    static func download(_ url: URL, to destination: URL, onProgress: @escaping @Sendable (Double?) -> Void) async throws {
        let downloader = Downloader(destination: destination, onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: downloader, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { continuation in
            downloader.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten written: Int64, totalBytesExpectedToWrite expected: Int64) {
        onProgress(expected > 0 ? Double(written) / Double(expected) : nil)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The temporary file is deleted when this method returns, so it has to be moved here.
        if let response = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            moveError = URLError(.badServerResponse)
            return
        }
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            moveError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error ?? moveError {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
        continuation = nil
    }
}
