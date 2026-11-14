import Foundation

/// Re-reads the friend list, falling back to the last list that read successfully.
public struct FriendListLoader {
    public private(set) var lastGood: [String]?
    public private(set) var error: String?

    public init() {}

    /// The current list, or the last good one if this read failed; nil until a read has
    /// ever succeeded, so callers can tell "no list yet" from "an empty list".
    public mutating func reload(from store: StateStore) -> [String]? {
        do {
            lastGood = try store.readFriendNames()
            error = nil
        } catch {
            self.error = "Couldn't read friends.txt — using the last list."
        }
        return lastGood
    }
}
