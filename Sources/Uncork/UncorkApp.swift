import AppKit
import SwiftUI

@main
struct UncorkApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup("Uncork") {
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

    /// Files dropped on the Dock icon or opened with "Open With → Uncork".
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            AppModel.shared.open(urls)
        }
    }
}
