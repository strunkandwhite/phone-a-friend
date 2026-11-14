import XCTest
@testable import FriendQueue

final class DisplayTextTests: XCTestCase {
    func testLastContactStrings() {
        XCTAssertEqual(DisplayText.lastContact(nil, today: d(20)), "Never contacted")
        XCTAssertEqual(DisplayText.lastContact(FriendRecord(lastSkipped: d(3)), today: d(20)), "Never contacted")
        XCTAssertEqual(DisplayText.lastContact(FriendRecord(lastContacted: d(20)), today: d(20)), "Last contact: today")
        XCTAssertEqual(DisplayText.lastContact(FriendRecord(lastContacted: d(19)), today: d(20)), "Last contact: yesterday")
        XCTAssertEqual(
            DisplayText.lastContact(FriendRecord(lastContacted: DayKey(year: 2025, month: 11, day: 27)), today: DayKey(year: 2026, month: 1, day: 13)),
            "Last contact: 47 days ago"
        )
        XCTAssertEqual(DisplayText.lastContact(FriendRecord(lastContacted: d(25)), today: d(20)), "Last contact: today")
    }
}
