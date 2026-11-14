import SwiftUI

@main
struct PhoneAFriendApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The status item and popover are owned by AppDelegate; an app needs at least one scene.
    var body: some Scene {
        Settings { EmptyView() }
    }
}
