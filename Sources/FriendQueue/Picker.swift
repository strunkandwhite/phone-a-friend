import Foundation

public enum Picker {
    /// Friends never touched (neither contacted nor skipped) come first; after that, the friend
    /// touched longest ago wins. Exact ties are broken at random. A skip counts as a touch, so a
    /// friend who wasn't reached goes to the back of the queue instead of returning the next day.
    public static func choose<G: RandomNumberGenerator>(
        from names: [String],
        records: [String: FriendRecord],
        using generator: inout G
    ) -> String? {
        func priority(_ name: String) -> (tier: Int, lastTouched: DayKey?) {
            let record = records[name] ?? FriendRecord()
            return (record.lastTouched == nil ? 0 : 1, record.lastTouched)
        }

        func isHigherPriority(_ a: (tier: Int, lastTouched: DayKey?), than b: (tier: Int, lastTouched: DayKey?)) -> Bool {
            if a.tier != b.tier { return a.tier < b.tier }
            switch (a.lastTouched, b.lastTouched) {
            case (nil, nil): return false
            case (nil, _?): return true
            case (_?, nil): return false
            case let (x?, y?): return x < y
            }
        }

        guard let best = names.map(priority).min(by: isHigherPriority) else { return nil }
        let tiedForBest = names.filter { name in
            let candidate = priority(name)
            return candidate.tier == best.tier && candidate.lastTouched == best.lastTouched
        }
        return tiedForBest.shuffled(using: &generator).first
    }
}
