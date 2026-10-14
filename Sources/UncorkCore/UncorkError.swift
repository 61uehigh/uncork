import Foundation

public enum UncorkError: LocalizedError, Equatable {
    case noRuntimeAsset
    case missingChecksum(String)
    case checksumMismatch(expected: String, actual: String)
    case wineBinaryNotFound
    case unsupportedFile(String)
    case commandFailed(String, Int32)

    public var errorDescription: String? {
        switch self {
        case .noRuntimeAsset:
            "Couldn't find a Wine build to download."
        case .missingChecksum(let name):
            "\(name) has no published checksum, so it can't be verified."
        case .checksumMismatch:
            "The downloaded Wine runtime is corrupted or was tampered with. Try again."
        case .wineBinaryNotFound:
            "The Wine runtime was extracted, but the wine executable is missing."
        case .unsupportedFile(let name):
            "\(name) isn't a Windows program (.exe or .msi)."
        case .commandFailed(let command, let status):
            "\(command) failed with exit code \(status)."
        }
    }
}
