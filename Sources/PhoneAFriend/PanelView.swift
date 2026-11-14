import AppKit
import FriendQueue
import SwiftUI

@MainActor
struct PanelView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.errorLine {
                Text(verbatim: error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            todaySection

            if !model.names.isEmpty {
                Divider()
                searchSection
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onAppear(perform: panelOpened)
        // MenuBarExtra keeps its window alive between openings, so onAppear may fire only once;
        // the panel is the app's only window, so its becoming key marks every opening.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            panelOpened()
        }
    }

    private func panelOpened() {
        model.refresh()
        query = ""
        // Wait a turn so the panel's window is key before taking focus.
        DispatchQueue.main.async { searchFocused = true }
    }

    @ViewBuilder
    private var todaySection: some View {
        if let pick = model.state.pick {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: pick.friend)
                    .font(.title2.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                // The record from before today's answer, so answering doesn't change this line mid-day.
                Text(verbatim: DisplayText.lastContact(pick.priorRecord, today: model.today))
                    .foregroundStyle(.secondary)
                HStack {
                    Button(label("Contacted", chosen: pick.answer == .contacted)) {
                        model.answer(pick.answer == .contacted ? nil : .contacted)
                    }
                    .buttonStyle(.borderedProminent)
                    Button(label("Not today", chosen: pick.answer == .skipped)) {
                        model.answer(pick.answer == .skipped ? nil : .skipped)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No friends yet — add names to your list")
                Button("Edit friend list…") { model.openFriendList() }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Log a contact")
                .font(.headline)
            TextField("Type a name…", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit {
                    // With no match (or a blank box), do nothing and keep the text so a typo can be fixed.
                    guard let topMatch = model.returnTarget(for: query) else { return }
                    model.toggleLog(topMatch)
                    query = ""
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.searchResults(for: query), id: \.self) { name in
                        resultRow(name)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private func resultRow(_ name: String) -> some View {
        Button {
            model.toggleLog(name)
        } label: {
            HStack {
                Text(verbatim: name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if model.loggedToday.contains(name) {
                    Text("✓ today")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Edit list…") { model.openFriendList() }
                Spacer()
                Toggle("Open at login", isOn: Binding(
                    get: { model.openAtLogin },
                    set: { model.setOpenAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            if model.openAtLoginFailed {
                Text("Couldn't turn on Open at login")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(_ title: String, chosen: Bool) -> String {
        chosen ? "✓ \(title)" : title
    }
}
