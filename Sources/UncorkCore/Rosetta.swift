import Foundation

/// The Mac Wine builds are x86_64, so Apple Silicon Macs need Rosetta 2 to run them.
public enum Rosetta {
    public static let installCommand = "softwareupdate --install-rosetta --agree-to-license"

    public static var isRequired: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }

    public static func isInstalled() async -> Bool {
        guard isRequired else { return true }
        let status = try? await Shell.run("/usr/bin/arch", ["-x86_64", "/usr/bin/true"])
        return status == 0
    }

    /// May fail without admin rights. Callers should then show `installCommand` to the user.
    public static func install() async throws {
        try await Shell.runChecked("/usr/sbin/softwareupdate", ["--install-rosetta", "--agree-to-license"])
    }
}
