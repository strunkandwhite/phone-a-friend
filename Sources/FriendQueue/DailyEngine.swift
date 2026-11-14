import Foundation

extension AppState {
    /// Brings the state up to `today` against the current list: resolves a stale pick, expires
    /// yesterday's logs, drops an unanswered pick whose friend left the list, and picks if needed.
    public mutating func refresh<G: RandomNumberGenerator>(names: [String], today: DayKey, using generator: inout G) {
        let listed = Set(names)

        // A pick dated after `today` (the clock moved backwards) stays current.
        if let stale = pick, stale.day < today {
            if stale.answer == nil, listed.contains(stale.friend) {
                friends[stale.friend, default: FriendRecord()].lastSkipped = stale.day
            }
            pick = nil
        }

        if let loggedOn = logDay, loggedOn < today {
            logDay = nil
            logPriors = [:]
        }

        if let current = pick, current.answer == nil, !listed.contains(current.friend) {
            pick = nil
        }

        if pick == nil, let chosen = Picker.choose(from: names, records: friends, using: &generator) {
            pick = DailyPick(day: today, friend: chosen, priorRecord: friends[chosen] ?? FriendRecord())
        }
    }

    /// Sets, changes or clears (nil) the answer for the current pick, undoing any earlier answer first.
    public mutating func setAnswer(_ answer: Answer?, today: DayKey) {
        guard var current = pick else { return }
        var record = current.priorRecord
        switch answer {
        case .contacted: record.lastContacted = current.day
        case .skipped: record.lastSkipped = current.day
        case nil: break
        }
        friends[current.friend] = record
        current.answer = answer
        pick = current
    }

    /// "Log a contact": marks a friend contacted today, or undoes today's log of them.
    /// Logging the current pick is the same as answering Contacted.
    public mutating func toggleLog(_ name: String, today: DayKey) {
        if let current = pick, current.friend == name {
            setAnswer(current.answer == .contacted ? nil : .contacted, today: today)
            return
        }

        if logDay == today, let prior = logPriors[name] {
            friends[name] = prior
            logPriors[name] = nil
            return
        }

        if logDay != today {
            logDay = today
            logPriors = [:]
        }
        logPriors[name] = friends[name] ?? FriendRecord()
        friends[name, default: FriendRecord()].lastContacted = today
    }

    public var isPending: Bool {
        guard let current = pick else { return false }
        return current.answer == nil
    }

    /// Friends marked contacted today: those logged via the submenu, plus the pick if answered Contacted.
    public func loggedToday(_ today: DayKey) -> Set<String> {
        var logged = logDay == today ? Set(logPriors.keys) : []
        if let current = pick, current.answer == .contacted {
            logged.insert(current.friend)
        }
        return logged
    }
}
