import AppKit
import Combine
import SwiftUI

/// Owns the menu bar icon and its popover. A popover is anchored to the icon by AppKit and
/// grows downward as its content changes, which SwiftUI's MenuBarExtra window did not do.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var iconSubscription: AnyCancellable?

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
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
