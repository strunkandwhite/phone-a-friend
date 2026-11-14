import XCTest
@testable import FriendQueue

final class DailyEngineTests: XCTestCase {
    private func refreshed(_ state: inout AppState, _ names: [String], _ today: DayKey, seed: UInt64 = 1) {
        var generator = SeededGenerator(seed: seed)
        state.refresh(names: names, today: today, using: &generator)
    }

    private func other(than name: String, in names: [String]) -> String {
        names.first { $0 != name }!
    }

    // MARK: Picking

    func testFirstRefreshPicksAndIsPending() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        XCTAssertEqual(state.pick?.day, d(5))
        XCTAssertTrue(state.isPending)
    }

    func testRefreshSameDayDoesNotReroll() {
        var state = AppState()
        refreshed(&state, ["A", "B", "C", "D"], d(5), seed: 1)
        let first = state.pick?.friend
        for seed in 2...20 {
            refreshed(&state, ["A", "B", "C", "D"], d(5), seed: UInt64(seed))
        }
        XCTAssertEqual(state.pick?.friend, first)
    }

    func testEmptyListHasNoPickAndIsNotPending() {
        var state = AppState()
        refreshed(&state, [], d(5))
        XCTAssertNil(state.pick)
        XCTAssertFalse(state.isPending)
    }

    func testNamesAddedMidDayGetAPick() {
        var state = AppState()
        refreshed(&state, [], d(5))
        refreshed(&state, ["A"], d(5))
        XCTAssertEqual(state.pick?.friend, "A")
        XCTAssertTrue(state.isPending)
    }

    // MARK: Answering

    func testContactedSetsLastContactedAndClearsPending() {
        var state = AppState()
        refreshed(&state, ["A"], d(5))
        state.setAnswer(.contacted, today: d(5))
        XCTAssertEqual(state.friends["A"]?.lastContacted, d(5))
        XCTAssertEqual(state.pick?.answer, .contacted)
        XCTAssertFalse(state.isPending)
    }

    func testNotTodaySetsLastSkippedAndClearsPending() {
        var state = AppState()
        refreshed(&state, ["A"], d(5))
        state.setAnswer(.skipped, today: d(5))
        XCTAssertEqual(state.friends["A"]?.lastSkipped, d(5))
        XCTAssertNil(state.friends["A"]?.lastContacted)
        XCTAssertFalse(state.isPending)
    }

    func testChangingAnswerRevertsPreviousEffect() {
        var state = AppState()
        state.friends["A"] = FriendRecord(lastContacted: d(1))
        refreshed(&state, ["A"], d(5))
        state.setAnswer(.contacted, today: d(5))
        state.setAnswer(.skipped, today: d(5))
        XCTAssertEqual(state.friends["A"], FriendRecord(lastContacted: d(1), lastSkipped: d(5)))
    }

    func testUnansweringRestoresPriorRecord() {
        var state = AppState()
        state.friends["A"] = FriendRecord(lastContacted: d(1), lastSkipped: d(2))
        refreshed(&state, ["A"], d(5))
        state.setAnswer(.contacted, today: d(5))
        state.setAnswer(nil, today: d(5))
        XCTAssertEqual(state.friends["A"], FriendRecord(lastContacted: d(1), lastSkipped: d(2)))
        XCTAssertTrue(state.isPending)
    }

    func testSetAnswerWithoutPickDoesNothing() {
        var state = AppState()
        state.setAnswer(.contacted, today: d(5))
        XCTAssertEqual(state, AppState())
    }

    // MARK: Rollover

    func testUnansweredPickBecomesSkipAtRollover() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let oldPick = state.pick!.friend
        refreshed(&state, ["A", "B"], d(6))
        XCTAssertEqual(state.friends[oldPick]?.lastSkipped, d(5))
        XCTAssertNil(state.friends[oldPick]?.lastContacted)
        XCTAssertEqual(state.pick?.day, d(6))
        XCTAssertTrue(state.isPending)
    }

    func testAnsweredPickIsFinalAfterRollover() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let oldPick = state.pick!.friend
        state.setAnswer(.contacted, today: d(5))
        refreshed(&state, ["A", "B"], d(6))
        state.setAnswer(.skipped, today: d(6))
        XCTAssertNotEqual(state.pick?.friend, oldPick)
        XCTAssertEqual(state.friends[oldPick], FriendRecord(lastContacted: d(5)))
    }

    func testWeeksAwayRecordsOneSkipOnly() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let oldPick = state.pick!.friend
        let otherFriend = other(than: oldPick, in: ["A", "B"])
        state.toggleLog(otherFriend, today: d(5))
        refreshed(&state, ["A", "B"], d(30))
        XCTAssertEqual(state.friends[oldPick], FriendRecord(lastSkipped: d(5)))
        XCTAssertEqual(state.friends[otherFriend], FriendRecord(lastContacted: d(5)))
        XCTAssertNil(state.logDay)
        XCTAssertEqual(state.logPriors, [:])
        XCTAssertEqual(state.pick?.day, d(30))
    }

    func testNextDayShowsSomeoneNewAfterNotToday() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let skipped = state.pick!.friend
        state.setAnswer(.skipped, today: d(5))
        refreshed(&state, ["A", "B"], d(6))
        XCTAssertEqual(state.pick?.friend, other(than: skipped, in: ["A", "B"]))
    }

    func testClockGoingBackwardsKeepsPick() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(10))
        let before = state
        refreshed(&state, ["A", "B"], d(9))
        XCTAssertEqual(state, before)
    }

    func testFullRotationVisitsEveryoneBeforeRepeating() {
        var state = AppState()
        let names = ["A", "B", "C", "D"]
        var picks: [String] = []
        for day in 1...5 {
            refreshed(&state, names, d(day), seed: UInt64(day))
            picks.append(state.pick!.friend)
            state.setAnswer(.contacted, today: d(day))
        }
        XCTAssertEqual(Set(picks[0..<4]), Set(names))
        XCTAssertEqual(picks[4], picks[0])
    }

    // MARK: Removing names

    func testRemovedUnansweredPickIsRepickedWithNothingRecorded() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let removed = state.pick!.friend
        let remaining = other(than: removed, in: ["A", "B"])
        refreshed(&state, [remaining], d(5))
        XCTAssertEqual(state.pick?.friend, remaining)
        XCTAssertEqual(state.pick?.day, d(5))
        XCTAssertTrue(state.isPending)
        XCTAssertEqual(state.friends[removed] ?? FriendRecord(), FriendRecord())
    }

    func testRemovedAnsweredPickKeepsDayAnswered() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let answered = state.pick!
        state.setAnswer(.contacted, today: d(5))
        refreshed(&state, [other(than: answered.friend, in: ["A", "B"])], d(5))
        XCTAssertEqual(state.pick?.friend, answered.friend)
        XCTAssertEqual(state.pick?.answer, .contacted)
        XCTAssertFalse(state.isPending)
    }

    func testRemovedPickNotSkippedAtRollover() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let removed = state.pick!.friend
        refreshed(&state, [other(than: removed, in: ["A", "B"])], d(6))
        XCTAssertNil(state.friends[removed]?.lastSkipped)
    }

    // MARK: Logging

    func testLoggingOtherFriendLeavesPickPending() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let otherFriend = other(than: state.pick!.friend, in: ["A", "B"])
        state.toggleLog(otherFriend, today: d(5))
        XCTAssertEqual(state.friends[otherFriend]?.lastContacted, d(5))
        XCTAssertTrue(state.isPending)
        XCTAssertEqual(state.loggedToday(d(5)), [otherFriend])
    }

    func testLoggingTwiceUndoesLog() {
        var state = AppState()
        state.friends["B"] = FriendRecord(lastContacted: d(1), lastSkipped: d(2))
        state.friends["A"] = FriendRecord()
        refreshed(&state, ["A", "B"], d(5))
        XCTAssertEqual(state.pick?.friend, "A")
        state.toggleLog("B", today: d(5))
        state.toggleLog("B", today: d(5))
        XCTAssertEqual(state.friends["B"], FriendRecord(lastContacted: d(1), lastSkipped: d(2)))
        XCTAssertEqual(state.loggedToday(d(5)), [])
    }

    func testLoggingTodaysPickEqualsContacted() {
        var state = AppState()
        state.friends["A"] = FriendRecord(lastSkipped: d(2))
        refreshed(&state, ["A"], d(5))
        state.toggleLog("A", today: d(5))
        XCTAssertEqual(state.pick?.answer, .contacted)
        XCTAssertEqual(state.friends["A"], FriendRecord(lastContacted: d(5), lastSkipped: d(2)))
        XCTAssertEqual(state.loggedToday(d(5)), ["A"])
        state.toggleLog("A", today: d(5))
        XCTAssertNil(state.pick?.answer)
        XCTAssertEqual(state.friends["A"], FriendRecord(lastSkipped: d(2)))
        XCTAssertEqual(state.loggedToday(d(5)), [])
    }

    func testLoggingTodaysPickAfterNotTodaySwitchesToContacted() {
        var state = AppState()
        refreshed(&state, ["A"], d(5))
        state.setAnswer(.skipped, today: d(5))
        state.toggleLog("A", today: d(5))
        XCTAssertEqual(state.pick?.answer, .contacted)
        XCTAssertEqual(state.friends["A"], FriendRecord(lastContacted: d(5)))
    }

    func testLogsBecomeFinalNextDay() {
        var state = AppState()
        refreshed(&state, ["A", "B"], d(5))
        let pickOnDay5 = state.pick!.friend
        let logged = other(than: pickOnDay5, in: ["A", "B"])
        state.toggleLog(logged, today: d(5))
        refreshed(&state, ["A", "B"], d(6))
        XCTAssertEqual(state.loggedToday(d(6)), [])
        state.toggleLog(logged, today: d(6))
        XCTAssertEqual(state.logPriors[logged], FriendRecord(lastContacted: d(5)))
        XCTAssertEqual(state.friends[logged]?.lastContacted, d(6))
    }
}
