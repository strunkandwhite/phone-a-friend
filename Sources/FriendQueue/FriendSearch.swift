import Foundation

public enum FriendSearch {
    /// Friends whose name starts with `query`, ignoring case and accents, in alphabetical order.
    /// A blank query matches nobody.
    public static func results(query: String, names: [String]) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let prefix = fold(trimmed)
        return names
            .filter { fold($0).hasPrefix(prefix) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
