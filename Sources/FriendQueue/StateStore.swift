import Foundation

public enum StateLoad: Equatable {
    /// No state file yet.
    case fresh
    case loaded(AppState)
    /// The state file couldn't be used; it was renamed to `movedTo` and a fresh state returned.
    case recovered(AppState, movedTo: URL)
}

/// Reads and writes the app's two files: the hand-edited `friends.txt` and the app-owned `state.json`.
public struct StateStore {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func defaultDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport.appendingPathComponent("PhoneAFriend", isDirectory: true)
    }

    public var friendsURL: URL { directory.appendingPathComponent("friends.txt") }
    public var stateURL: URL { directory.appendingPathComponent("state.json") }
    private var corruptStateURL: URL { directory.appendingPathComponent("state.corrupt.json") }

    /// Creates the directory and a commented template list, never touching an existing list.
    public func ensureFriendListExists() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard !FileManager.default.fileExists(atPath: friendsURL.path) else { return }
        try Data(FriendList.template.utf8).write(to: friendsURL, options: .withoutOverwriting)
    }

    public func readFriendNames() throws -> [String] {
        FriendList.parse(try String(contentsOf: friendsURL, encoding: .utf8))
    }

    public func loadState() -> StateLoad {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return .fresh }
        if let data = try? Data(contentsOf: stateURL),
           let state = try? JSONDecoder().decode(AppState.self, from: data),
           state.version <= AppState.currentVersion {
            return .loaded(state)
        }
        // Keep the unusable file so history can be recovered by hand rather than silently lost.
        try? FileManager.default.removeItem(at: corruptStateURL)
        do {
            try FileManager.default.moveItem(at: stateURL, to: corruptStateURL)
        } catch {
            return .recovered(AppState(), movedTo: stateURL)
        }
        return .recovered(AppState(), movedTo: corruptStateURL)
    }

    public func save(_ state: AppState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: stateURL, options: .atomic)
    }
}
