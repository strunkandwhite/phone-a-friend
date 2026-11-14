import Foundation

/// The hand-edited friend list: one name per line, `#` comments and blank lines ignored.
public enum FriendList {
    public static let template = """
    # Phone a Friend — one name per line.
    # Blank lines and lines starting with # are ignored.

    """

    /// Names in file order, trimmed, with exact duplicates collapsed (first occurrence wins).
    public static func parse(_ text: String) -> [String] {
        let withoutByteOrderMark = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        var seen = Set<String>()
        var names: [String] = []
        for line in withoutByteOrderMark.components(separatedBy: .newlines) {
            let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !name.hasPrefix("#"), !seen.contains(name) else { continue }
            seen.insert(name)
            names.append(name)
        }
        return names
    }
}
