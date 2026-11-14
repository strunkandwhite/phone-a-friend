import Foundation

public enum FriendSearch {
    /// Friends matching `query`, ignoring case and accents, with names where a word starts with
    /// the query ranked first. An empty query lists the friends logged today, so an undo is
    /// always one click away.
    public static func results(query: String, names: [String], loggedToday: Set<String>) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return alphabetical(names.filter { loggedToday.contains($0) })
        }

        let needle = fold(trimmed)
        var wordStartMatches: [String] = []
        var otherMatches: [String] = []
        for name in names {
            let haystack = fold(name)
            if haystack.hasPrefix(needle) || haystack.contains(" " + needle) {
                wordStartMatches.append(name)
            } else if haystack.contains(needle) {
                otherMatches.append(name)
            }
        }
        return alphabetical(wordStartMatches) + alphabetical(otherMatches)
    }

    /// The friend Return should act on: the top match, or nobody for a blank query. The blank-query
    /// list is today's logs shown for undo, not matches, so Return must not toggle one of them.
    public static func returnTarget(query: String, names: [String], loggedToday: Set<String>) -> String? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return results(query: query, names: names, loggedToday: loggedToday).first
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func alphabetical(_ names: [String]) -> [String] {
        names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
