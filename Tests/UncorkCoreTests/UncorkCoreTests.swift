import Foundation
import Testing
@testable import UncorkCore

@Suite struct WineReleaseCatalogTests {
    private func releases(_ entries: [(tag: String, prerelease: Bool, assets: [String])]) -> Data {
        let json = entries.map { entry in
            [
                "tag_name": entry.tag,
                "prerelease": entry.prerelease,
                "assets": entry.assets.map { name in
                    [
                        "name": name,
                        "size": 100,
                        "browser_download_url": "https://example.com/\(name)",
                        "digest": "sha256:abc123",
                    ] as [String: Any]
                },
            ] as [String: Any]
        }
        return try! JSONSerialization.data(withJSONObject: json)
    }

    @Test func prefersNewestStableOverNewerDevel() throws {
        let data = releases([
            ("11.18", false, ["wine-devel-11.18-osx64.tar.xz", "wine-staging-11.18-osx64.tar.xz"]),
            ("11.0_1", false, ["wine-stable-11.0_1-osx64.tar.xz"]),
            ("10.0", false, ["wine-stable-10.0-osx64.tar.xz"]),
        ])
        let asset = try WineReleaseCatalog.pickAsset(fromReleasesJSON: data)
        #expect(asset.name == "wine-stable-11.0_1-osx64.tar.xz")
        #expect(asset.version == "11.0_1")
        #expect(asset.sha256 == "abc123")
    }

    @Test func fallsBackToDevelButNeverStaging() throws {
        let data = releases([
            ("11.19", false, ["wine-staging-11.19-osx64.tar.xz"]),
            ("11.18", false, ["wine-devel-11.18-osx64.tar.xz"]),
        ])
        #expect(try WineReleaseCatalog.pickAsset(fromReleasesJSON: data).name == "wine-devel-11.18-osx64.tar.xz")
    }

    @Test func skipsPrereleases() throws {
        let data = releases([
            ("12.0-rc1", true, ["wine-stable-12.0-rc1-osx64.tar.xz"]),
            ("11.0_1", false, ["wine-stable-11.0_1-osx64.tar.xz"]),
        ])
        #expect(try WineReleaseCatalog.pickAsset(fromReleasesJSON: data).version == "11.0_1")
    }

    @Test func throwsWhenNothingMatches() {
        let data = releases([("11.19", false, ["wine-staging-11.19-osx64.tar.xz"])])
        #expect(throws: UncorkError.noRuntimeAsset) { try WineReleaseCatalog.pickAsset(fromReleasesJSON: data) }
    }
}

@Suite struct PrefixManagerTests {
    private func temporaryPaths() -> UncorkPaths {
        UncorkPaths(root: FileManager.default.temporaryDirectory.appending(path: "uncork-tests-\(UUID().uuidString)"))
    }

    @Test func prefixIDIsStableAndPathSpecific() {
        let a = URL(filePath: "/Users/me/Downloads/Setup Tool.exe")
        let b = URL(filePath: "/Users/me/Desktop/Setup Tool.exe")
        #expect(PrefixManager.prefixID(for: a) == PrefixManager.prefixID(for: a))
        #expect(PrefixManager.prefixID(for: a) != PrefixManager.prefixID(for: b))
        #expect(PrefixManager.prefixID(for: a).hasPrefix("Setup_Tool-"))
    }

    @Test func recentIsNewestFirst() throws {
        let paths = temporaryPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let manager = PrefixManager(paths: paths)
        _ = try manager.recordRun(of: URL(filePath: "/tmp/old.exe"), at: Date(timeIntervalSince1970: 1_000))
        _ = try manager.recordRun(of: URL(filePath: "/tmp/new.exe"), at: Date(timeIntervalSince1970: 2_000))
        #expect(manager.recent().map(\.displayName) == ["new", "old"])
    }
}

@Suite struct RuntimeManagerTests {
    @Test func sha256MatchesKnownValue() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "uncork-hash-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("abc".utf8).write(to: file)
        #expect(try RuntimeManager.sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func wineserverSitsNextToWine() {
        let runtime = WineRuntime(version: "11.0", wineBinary: URL(filePath: "/rt/Wine Stable.app/Contents/Resources/wine/bin/wine"))
        #expect(runtime.wineserverBinary.path == "/rt/Wine Stable.app/Contents/Resources/wine/bin/wineserver")
    }

    @Test func shellStopsCommandsThatOutliveTheirTimeout() async throws {
        let start = ContinuousClock.now
        let status = try await Shell.run("/bin/sleep", ["10"], timeout: .milliseconds(200))
        #expect(status != 0)
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test func stopsProcessesRunningFromADirectory() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "uncork-procs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sleeper = folder.appending(path: "sleep")
        try FileManager.default.copyItem(at: URL(filePath: "/bin/sleep"), to: sleeper)

        let process = Process()
        process.executableURL = sleeper
        process.arguments = ["30"]
        try process.run()
        defer { if process.isRunning { process.terminate() } }

        #expect(WineProcesses.running(from: folder) == [process.processIdentifier])
        await WineProcesses.stop([process.processIdentifier])
        process.waitUntilExit()
        #expect(WineProcesses.running(from: folder).isEmpty)
    }

    @Test func onlyMatchesProcessesInUncorkPrefixes() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "uncork-env-\(UUID().uuidString)")
        let runtimes = folder.appending(path: "Runtime")
        let prefixes = folder.appending(path: "Prefixes")
        try FileManager.default.createDirectory(at: runtimes, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sleeper = runtimes.appending(path: "sleep")
        try FileManager.default.copyItem(at: URL(filePath: "/bin/sleep"), to: sleeper)

        func start(prefix: String) throws -> Process {
            let process = Process()
            process.executableURL = sleeper
            // An argument that looks like the variable must not be mistaken for it.
            process.arguments = ["WINEPREFIX=/not/this/one", "30"]
            process.environment = ["WINEPREFIX": prefix]
            try process.run()
            return process
        }
        let ours = try start(prefix: prefixes.appending(path: "App-1234abcd").path)
        let someoneElses = try start(prefix: folder.appending(path: "elsewhere").path)
        defer { [ours, someoneElses].forEach { if $0.isRunning { $0.terminate() } } }

        #expect(WineProcesses.environmentValue("WINEPREFIX", of: ours.processIdentifier) == prefixes.appending(path: "App-1234abcd").path)
        #expect(WineProcesses.running(fromRuntimes: runtimes, inPrefixes: prefixes) == [ours.processIdentifier])
    }

    @Test func launcherAcceptsOnlyWindowsPrograms() {
        #expect(Launcher.isSupported(URL(filePath: "/tmp/App.EXE")))
        #expect(Launcher.isSupported(URL(filePath: "/tmp/setup.msi")))
        #expect(!Launcher.isSupported(URL(filePath: "/tmp/readme.txt")))
    }
}
