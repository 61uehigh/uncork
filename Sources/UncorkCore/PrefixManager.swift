import CryptoKit
import Foundation

/// A Windows program Uncork has run, with its own Wine prefix.
public struct PrefixRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let programPath: String
    public var lastRun: Date

    public var programURL: URL { URL(filePath: programPath) }
    public var displayName: String { programURL.deletingPathExtension().lastPathComponent }
}

/// Gives every program its own prefix so programs can't break each other's settings or DLLs.
public struct PrefixManager: Sendable {
    static let recordFileName = "uncork.json"

    public let paths: UncorkPaths

    public init(paths: UncorkPaths = UncorkPaths()) {
        self.paths = paths
    }

    /// Stable per program path: `<sanitized name>-<first 8 hex of SHA-256(path)>`.
    public static func prefixID(for program: URL) -> String {
        let path = program.standardizedFileURL.path
        let hash = SHA256.hash(data: Data(path.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
        let stem = program.deletingPathExtension().lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = String(stem.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }).prefix(40)
        return "\(sanitized.isEmpty ? "program" : String(sanitized))-\(hash)"
    }

    public func prefixURL(id: String) -> URL {
        paths.prefixes.appending(path: id, directoryHint: .isDirectory)
    }

    public func logURL(id: String) -> URL {
        paths.logs.appending(path: "\(id).log")
    }

    /// Creates the prefix folder if needed and stamps the run time.
    public func recordRun(of program: URL, at date: Date = .now) throws -> PrefixRecord {
        let id = Self.prefixID(for: program)
        let folder = prefixURL(id: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let record = PrefixRecord(id: id, programPath: program.standardizedFileURL.path, lastRun: date)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(to: folder.appending(path: Self.recordFileName), options: .atomic)
        return record
    }

    /// Programs run before, most recent first.
    public func recent() -> [PrefixRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let folders = (try? FileManager.default.contentsOfDirectory(at: paths.prefixes, includingPropertiesForKeys: nil)) ?? []
        return folders
            .compactMap { try? Data(contentsOf: $0.appending(path: Self.recordFileName)) }
            .compactMap { try? decoder.decode(PrefixRecord.self, from: $0) }
            .sorted { $0.lastRun > $1.lastRun }
    }
}
