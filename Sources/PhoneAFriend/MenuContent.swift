import AppKit
import FriendQueue
import SwiftUI

@MainActor
struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let error = model.errorLine {
            Text(verbatim: error)
        }

        if let pick = model.state.pick {
            Text(verbatim: "Today: \(pick.friend)")
            // The record from before today's answer, so answering doesn't change this line mid-day.
            Text(verbatim: DisplayText.lastContact(pick.priorRecord, today: model.today))
            Divider()
            Toggle("Contacted", isOn: answerBinding(.contacted))
            Toggle("Not today", isOn: answerBinding(.skipped))
        } else {
            Text("No friends yet — add names to your list")
        }

        Divider()

        if !model.names.isEmpty {
            Menu("Log a contact") {
                ForEach(model.sortedNames, id: \.self) { name in
                    Toggle(name, isOn: Binding(
                        get: { model.loggedToday.contains(name) },
                        set: { _ in model.toggleLog(name) }
                    ))
                }
            }
        }
        Button("Edit friend list…") { model.openFriendList() }
        Toggle("Open at login", isOn: Binding(
            get: { model.openAtLogin },
            set: { model.setOpenAtLogin($0) }
        ))
        if model.openAtLoginFailed {
            Text("Couldn't turn on Open at login")
        }

        Divider()

        Button("Quit") { NSApplication.shared.terminate(nil) }
    }

    private func answerBinding(_ answer: Answer) -> Binding<Bool> {
        Binding(
            get: { model.state.pick?.answer == answer },
            set: { isOn in model.answer(isOn ? answer : nil) }
        )
    }
}
