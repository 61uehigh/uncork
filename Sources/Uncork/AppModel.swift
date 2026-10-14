import AppKit
import Observation
import UncorkCore

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    enum RuntimeState: Equatable {
        case checking
        case missing
        case installing(InstallPhase)
        case ready(WineRuntime)
        case failed(String)
    }

    enum RunState: Equatable {
        case running
        case exited(Int32)
    }

    private(set) var runtimeState: RuntimeState = .checking
    private(set) var rosettaMissing = false
    private(set) var rosettaInstalling = false
    private(set) var recent: [PrefixRecord] = []
    private(set) var runStates: [String: RunState] = [:]
    var alertMessage: String?
    // View state lives here because @State needs SwiftUI's macro plugin, which only ships with full Xcode.
    var isDropTargeted = false
    var isPickingFile = false

    private let runtimes = RuntimeManager()
    private let prefixes = PrefixManager()
    /// Programs opened before the runtime was ready. They start as soon as setup finishes.
    private var pending: [URL] = []
    private var started = false

    private init() {}

    func start() async {
        guard !started else { return }
        started = true
        recent = prefixes.recent()
        if let runtime = runtimes.installed() {
            runtimeState = .ready(runtime)
        } else {
            runtimeState = .missing
        }
        // Finder may hand us files before startup finishes.
        let queued = pending
        pending = []
        open(queued)
        rosettaMissing = !(await Rosetta.isInstalled())
    }

    func installRuntime() async {
        switch runtimeState {
        case .checking, .installing, .ready: return
        case .missing, .failed: break
        }
        runtimeState = .installing(.resolving)
        do {
            let runtime = try await runtimes.install { phase in
                Task { @MainActor in
                    if case .installing = AppModel.shared.runtimeState {
                        AppModel.shared.runtimeState = .installing(phase)
                    }
                }
            }
            runtimeState = .ready(runtime)
            let queued = pending
            pending = []
            open(queued)
        } catch {
            runtimeState = .failed(error.localizedDescription)
        }
    }

    func installRosetta() async {
        rosettaInstalling = true
        defer { rosettaInstalling = false }
        do {
            try await Rosetta.install()
            rosettaMissing = !(await Rosetta.isInstalled())
        } catch {
            alertMessage = "Couldn't install Rosetta automatically. Run this in Terminal:\n\n\(Rosetta.installCommand)"
        }
    }

    /// Entry point for drag and drop, the file picker, and Finder's "Open With".
    func open(_ urls: [URL]) {
        let programs = urls.filter(Launcher.isSupported)
        if programs.count < urls.count {
            alertMessage = "Uncork can only open Windows programs (.exe or .msi)."
        }
        guard !programs.isEmpty else { return }

        guard case .ready(let runtime) = runtimeState else {
            pending.append(contentsOf: programs)
            if runtimeState != .checking {
                Task { await installRuntime() }
            }
            return
        }
        let launcher = Launcher(runtime: runtime, prefixes: prefixes)
        for program in programs {
            do {
                let record = try launcher.launch(program) { status in
                    Task { @MainActor in
                        AppModel.shared.runStates[PrefixManager.prefixID(for: program)] = .exited(status)
                    }
                }
                runStates[record.id] = .running
            } catch {
                alertMessage = error.localizedDescription
            }
        }
        recent = prefixes.recent()
    }

    func revealLog(of record: PrefixRecord) {
        let log = prefixes.logURL(id: record.id)
        if FileManager.default.fileExists(atPath: log.path) {
            NSWorkspace.shared.open(log)
        } else {
            alertMessage = "There's no log yet for \(record.displayName)."
        }
    }

    /// Programs started from this window that haven't exited yet.
    var runningCount: Int {
        runStates.values.filter { $0 == .running }.count
    }

    /// Stops all Windows programs and Wine background services in every known prefix, including ones left over from
    /// an earlier session that didn't shut down cleanly.
    func shutDown() async {
        guard let runtime = runtimes.installed() else { return }
        let ids = prefixes.recent().map(\.id)
        await Launcher(runtime: runtime, prefixes: prefixes).stopAll(prefixIDs: ids)
    }

    func revealPrefix(of record: PrefixRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([prefixes.prefixURL(id: record.id)])
    }
}
