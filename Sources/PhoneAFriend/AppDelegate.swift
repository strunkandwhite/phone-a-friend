import AppKit
import Combine
import SwiftUI

/// Owns the menu bar icon and its popover. A popover is anchored to the icon by AppKit and
/// grows downward as its content changes, which SwiftUI's MenuBarExtra window did not do.
///
/// The app starts here with a plain AppKit lifecycle rather than a SwiftUI `App`: a SwiftUI app
/// must declare a scene, and macOS would show that scene's (empty) window on activation.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // run() never returns, so `delegate` outlives the application's weak reference to it.
        application.run()
    }

    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var iconSubscription: AnyCancellable?
    private var escapeMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover(_:))

        popover.behavior = .transient
        popover.animates = true

        iconSubscription = model.$state
            .map(\.isPending)
            .removeDuplicates()
            .sink { [weak self] pending in
                self?.statusItem.button?.image = StatusIcon.image(pending: pending)
            }

        // While the search box is being edited it swallows Escape, so close the popover here.
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let escapeKeyCode: UInt16 = 53
            guard let self, event.keyCode == escapeKeyCode, self.popover.isShown else { return event }
            self.popover.performClose(nil)
            return nil
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }

        model.refresh()
        // A fresh controller each time gives the panel fresh view state (an empty search box).
        let controller = NSHostingController(rootView: PanelView(model: model))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller

        // A menu bar app isn't active by default; activating lets the search box take typing.
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // AppKit focuses the first text field when the popover's window becomes key; the search
        // box should wait for a click instead.
        DispatchQueue.main.async { [weak controller] in
            controller?.view.window?.makeFirstResponder(nil)
        }
    }
}
