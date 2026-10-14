import AppKit
import SwiftUI

@main
struct UncorkApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // A single window: opening the app again, opening a file with it or clicking the Dock icon brings this
        // window forward instead of making another copy of it.
        Window("Uncork", id: "main") {
            ContentView(model: .shared)
                .frame(minWidth: 460, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when started with `swift run`, which has no app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()

        // `Uncork path/to/program.exe` opens the program, the same as dropping it on the window.
        let programs = CommandLine.arguments.dropFirst()
            .filter { !$0.hasPrefix("-") }
            .map { URL(filePath: $0).absoluteURL }
        if !programs.isEmpty {
            MainActor.assumeIsolated {
                AppModel.shared.open(Array(programs))
            }
        }
    }

    /// Asks before closing programs that are still running, then stops Wine in every prefix before quitting.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            let model = AppModel.shared
            let running = model.runningCount
            if running > 0 {
                let alert = NSAlert()
                alert.messageText = running == 1
                    ? "Quit Uncork and close the Windows program that's still running?"
                    : "Quit Uncork and close the \(running) Windows programs that are still running?"
                alert.informativeText = running == 1
                    ? "Any unsaved work in it will be lost."
                    : "Any unsaved work in them will be lost."
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
            }
            Task { @MainActor in
                await model.shutDown()
                NSApp.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }

    /// Files dropped on the Dock icon or opened with "Open With → Uncork".
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            AppModel.shared.open(urls)
        }
    }
}
