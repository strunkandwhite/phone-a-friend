@testable import FriendQueue

/// Deterministic SplitMix64 so tests can pin random tie-breaks.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A day in January 2026, for compact test fixtures.
func d(_ day: Int) -> DayKey {
    DayKey(year: 2026, month: 1, day: day)
}
