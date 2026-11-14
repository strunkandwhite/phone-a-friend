import FriendQueue
import SwiftUI

@main
struct PhoneAFriendApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            StatusIcon(pending: model.state.isPending)
        }
        .menuBarExtraStyle(.menu)
    }
}
