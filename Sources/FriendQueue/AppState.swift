import Foundation

public struct FriendRecord: Codable, Equatable {
    public var lastContacted: DayKey?
    public var lastSkipped: DayKey?

    public init(lastContacted: DayKey? = nil, lastSkipped: DayKey? = nil) {
        self.lastContacted = lastContacted
        self.lastSkipped = lastSkipped
    }

    /// The later of the last contact and the last "Not today", or nil if neither happened.
    public var lastTouched: DayKey? {
        switch (lastContacted, lastSkipped) {
        case let (contacted?, skipped?): return max(contacted, skipped)
        case let (contacted?, nil): return contacted
        case let (nil, skipped?): return skipped
        case (nil, nil): return nil
        }
    }
}

public enum Answer: String, Codable {
    case contacted
    case skipped
}

public struct DailyPick: Codable, Equatable {
    public var day: DayKey
    public var friend: String
    public var answer: Answer?
    /// The friend's record when the pick was made, so any answer can be reverted exactly.
    public var priorRecord: FriendRecord

    public init(day: DayKey, friend: String, answer: Answer? = nil, priorRecord: FriendRecord) {
        self.day = day
        self.friend = friend
        self.answer = answer
        self.priorRecord = priorRecord
    }
}

public struct AppState: Codable, Equatable {
    public static let currentVersion = 1

    public var version = AppState.currentVersion
    public var friends: [String: FriendRecord] = [:]
    public var pick: DailyPick?
    /// The day the entries in `logPriors` were logged; they can be undone only on that day.
    public var logDay: DayKey?
    /// Friends logged via "Log a contact" (other than the pick), with their record from before the log.
    public var logPriors: [String: FriendRecord] = [:]
    public var loginItemInitialized = false

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, friends, pick, logDay, logPriors, loginItemInitialized
    }

    // Missing keys fall back to defaults so state files written by earlier builds still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? AppState.currentVersion
        friends = try container.decodeIfPresent([String: FriendRecord].self, forKey: .friends) ?? [:]
        pick = try container.decodeIfPresent(DailyPick.self, forKey: .pick)
        logDay = try container.decodeIfPresent(DayKey.self, forKey: .logDay)
        logPriors = try container.decodeIfPresent([String: FriendRecord].self, forKey: .logPriors) ?? [:]
        loginItemInitialized = try container.decodeIfPresent(Bool.self, forKey: .loginItemInitialized) ?? false
    }
}
