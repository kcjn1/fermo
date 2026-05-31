import AppKit
import SwiftUI

@main
struct FermoApp: App {
    @NSApplicationDelegateAdaptor(FermoApplicationDelegate.self) private var appDelegate
    @StateObject private var model: FermoViewModel

    init() {
        let model = FermoViewModel()
        _model = StateObject(wrappedValue: model)
        FermoMainWindowPresenter.shared.configure(model: model)
    }

    var body: some Scene {
        MenuBarExtra("Fermo", systemImage: "lock.shield") {
            FermoMenuView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

private final class FermoApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            FermoMainWindowPresenter.shared.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FermoMainWindowPresenter.shared.show()
        return true
    }
}

@MainActor
final class FermoMainWindowPresenter {
    static let shared = FermoMainWindowPresenter()

    private var model: FermoViewModel?
    private var window: NSWindow?

    func configure(model: FermoViewModel) {
        self.model = model
    }

    func show() {
        guard let model else {
            return
        }

        let window = window ?? makeWindow(model: model)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeWindow(model: FermoViewModel) -> NSWindow {
        let hostingController = NSHostingController(rootView: FermoDashboardView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Fermo"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1100, height: 760))
        window.minSize = NSSize(width: 980, height: 680)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
