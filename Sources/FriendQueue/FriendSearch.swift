import Foundation

public enum FriendSearch {
    /// Friends matching `query`, ignoring case and accents, with names where a word starts with
    /// the query ranked first. A blank query matches nobody.
    public static func results(query: String, names: [String]) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

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

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func alphabetical(_ names: [String]) -> [String] {
        names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
