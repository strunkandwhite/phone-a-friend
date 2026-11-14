import XCTest
@testable import FriendQueue

final class PickerTests: XCTestCase {
    func testEmptyListPicksNobody() {
        var generator = SeededGenerator(seed: 1)
        XCTAssertNil(Picker.choose(from: [], records: [:], using: &generator))
    }

    func testNeverTouchedTierBeatsLongAgoContact() {
        var generator = SeededGenerator(seed: 1)
        let records = ["Old": FriendRecord(lastContacted: d(1))]
        XCTAssertEqual(Picker.choose(from: ["Old", "New"], records: records, using: &generator), "New")
    }

    func testSkippedNeverContactedFriendGoesToBackOfWholeQueue() {
        var generator = SeededGenerator(seed: 1)
        let records = ["Contacted": FriendRecord(lastContacted: d(1)), "Skipped": FriendRecord(lastSkipped: d(2))]
        XCTAssertEqual(Picker.choose(from: ["Contacted", "Skipped"], records: records, using: &generator), "Contacted")
    }

    func testSkippedFriendStillBeatsFriendsTouchedMoreRecently() {
        var generator = SeededGenerator(seed: 1)
        let records = ["Recent": FriendRecord(lastContacted: d(9)), "Skipped": FriendRecord(lastSkipped: d(2))]
        XCTAssertEqual(Picker.choose(from: ["Recent", "Skipped"], records: records, using: &generator), "Skipped")
    }

    func testWithinTierOldestLastTouchedWins() {
        var generator = SeededGenerator(seed: 1)
        let records = [
            "A": FriendRecord(lastContacted: d(5)),
            "B": FriendRecord(lastContacted: d(2)),
            "C": FriendRecord(lastContacted: d(9)),
        ]
        XCTAssertEqual(Picker.choose(from: ["A", "B", "C"], records: records, using: &generator), "B")
    }

    func testSkipCountsAsTouchedButNotContacted() {
        var generator = SeededGenerator(seed: 1)
        let records = [
            "A": FriendRecord(lastContacted: d(3)),
            "B": FriendRecord(lastContacted: d(1), lastSkipped: d(10)),
        ]
        XCTAssertEqual(Picker.choose(from: ["A", "B"], records: records, using: &generator), "A")
    }

    func testNeverTouchedComesBeforeSkipped() {
        var generator = SeededGenerator(seed: 1)
        let records = ["Skipped": FriendRecord(lastSkipped: d(4))]
        XCTAssertEqual(Picker.choose(from: ["Skipped", "Fresh"], records: records, using: &generator), "Fresh")
    }

    func testTiesAreBrokenRandomly() {
        let firstPicks = Set((0..<50).map { seed -> String in
            var generator = SeededGenerator(seed: UInt64(seed))
            return Picker.choose(from: ["A", "B", "C"], records: [:], using: &generator)!
        })
        XCTAssertEqual(firstPicks, ["A", "B", "C"])
    }

    func testRecordsForRemovedNamesAreIgnored() {
        var generator = SeededGenerator(seed: 1)
        let records = ["Gone": FriendRecord(), "A": FriendRecord(lastContacted: d(1))]
        XCTAssertEqual(Picker.choose(from: ["A"], records: records, using: &generator), "A")
    }

    func testSingleFriendIsAlwaysPicked() {
        var generator = SeededGenerator(seed: 1)
        let records = ["Solo": FriendRecord(lastContacted: d(1), lastSkipped: d(2))]
        XCTAssertEqual(Picker.choose(from: ["Solo"], records: records, using: &generator), "Solo")
    }

    func testLastTouchedIsTheLaterOfContactAndSkip() {
        XCTAssertNil(FriendRecord().lastTouched)
        XCTAssertEqual(FriendRecord(lastContacted: d(3), lastSkipped: d(7)).lastTouched, d(7))
        XCTAssertEqual(FriendRecord(lastContacted: d(8), lastSkipped: d(7)).lastTouched, d(8))
        XCTAssertEqual(FriendRecord(lastContacted: d(8)).lastTouched, d(8))
    }
}
