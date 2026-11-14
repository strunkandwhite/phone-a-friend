import AppKit
import FriendQueue
import SwiftUI

@MainActor
struct PanelView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""

    private static let resultRowHeight: CGFloat = 24
    private static let visibleResultRows = 8

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
                .onSubmit {
                    // With no match (or a blank box), do nothing and keep the text so a typo can be fixed.
                    guard let topMatch = model.searchResults(for: query).first else { return }
                    model.toggleLog(topMatch)
                    query = ""
                }
            resultsList(model.searchResults(for: query))
        }
    }

    // The panel sizes itself to its content, and a ScrollView with only a maximum height
    // reports no height of its own and collapses to nothing, so give it an explicit one.
    private func resultsList(_ results: [String]) -> some View {
        let visibleRows = min(results.count, Self.visibleResultRows)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(results, id: \.self) { name in
                    resultRow(name)
                }
            }
        }
        .frame(height: CGFloat(visibleRows) * Self.resultRowHeight)
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
            .frame(height: Self.resultRowHeight)
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
