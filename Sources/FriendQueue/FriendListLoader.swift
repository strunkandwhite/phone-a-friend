import Foundation

/// Re-reads the friend list, falling back to the last list that read successfully.
public struct FriendListLoader {
    public private(set) var lastGood: [String] = []
    public private(set) var error: String?

    public init() {}

    public mutating func reload(from store: StateStore) -> [String] {
        do {
            lastGood = try store.readFriendNames()
            error = nil
        } catch {
            self.error = "Couldn't read friends.txt — using the last list."
        }
        return lastGood
    }
}
