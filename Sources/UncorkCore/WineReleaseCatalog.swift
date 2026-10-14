import Foundation

/// A downloadable Wine build.
public struct WineAsset: Sendable, Equatable {
    public let name: String
    public let version: String
    public let downloadURL: URL
    public let size: Int
    /// Hex SHA-256 published by GitHub for the asset, if any.
    public let sha256: String?
}

/// Picks a Wine build from Gcenx's macOS builds (https://github.com/Gcenx/macOS_Wine_builds),
/// the same builds Homebrew's disabled `wine-stable` cask used to install.
public enum WineReleaseCatalog {
    static let releasesURL = URL(string: "https://api.github.com/repos/Gcenx/macOS_Wine_builds/releases?per_page=100")!

    public static func fetchLatest(session: URLSession = .shared) async throws -> WineAsset {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await session.data(for: request)
        return try pickAsset(fromReleasesJSON: data)
    }

    /// Prefers the newest `wine-stable` build and falls back to the newest `wine-devel` one.
    /// `wine-staging` is skipped: it carries experimental patches.
    public static func pickAsset(fromReleasesJSON data: Data) throws -> WineAsset {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let releases = try decoder.decode([Release].self, from: data)
            .filter { !$0.prerelease && !($0.draft ?? false) }

        for channel in ["wine-stable-", "wine-devel-"] {
            for release in releases {
                if let asset = release.assets.first(where: { $0.name.hasPrefix(channel) && $0.name.hasSuffix("-osx64.tar.xz") }) {
                    return WineAsset(
                        name: asset.name,
                        version: release.tagName,
                        downloadURL: asset.browserDownloadUrl,
                        size: asset.size,
                        sha256: asset.digest.flatMap { $0.hasPrefix("sha256:") ? String($0.dropFirst(7)) : nil }
                    )
                }
            }
        }
        throw UncorkError.noRuntimeAsset
    }

    private struct Release: Decodable {
        let tagName: String
        let prerelease: Bool
        let draft: Bool?
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let size: Int
        let browserDownloadUrl: URL
        let digest: String?
    }
}
