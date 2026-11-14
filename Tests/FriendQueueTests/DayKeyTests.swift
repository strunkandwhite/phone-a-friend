import Foundation
import XCTest
@testable import FriendQueue

final class DayKeyTests: XCTestCase {
    func testStringRoundTrip() {
        XCTAssertEqual(DayKey(string: "2026-03-07")?.string, "2026-03-07")
    }

    func testRejectsGarbage() {
        XCTAssertNil(DayKey(string: "2026-3-7x"))
        XCTAssertNil(DayKey(string: "2026-13-01"))
        XCTAssertNil(DayKey(string: ""))
    }

    func testOrdering() {
        XCTAssertLessThan(DayKey(year: 2026, month: 12, day: 31), DayKey(year: 2027, month: 1, day: 1))
    }

    func testDaysSinceAcrossYearAndDST() {
        XCTAssertEqual(DayKey(year: 2027, month: 1, day: 2).days(since: DayKey(year: 2026, month: 12, day: 30)), 3)
        XCTAssertEqual(DayKey(year: 2026, month: 3, day: 9).days(since: DayKey(year: 2026, month: 3, day: 7)), 2)
        XCTAssertEqual(DayKey(year: 2026, month: 1, day: 1).days(since: DayKey(year: 2026, month: 1, day: 3)), -2)
    }

    func testFromDateUsesGivenTimeZone() {
        let lateEveningInLosAngeles = ISO8601DateFormatter().date(from: "2026-11-15T06:30:00Z")!
        XCTAssertEqual(DayKey(lateEveningInLosAngeles, timeZone: TimeZone(identifier: "America/Los_Angeles")!).string, "2026-11-14")
        XCTAssertEqual(DayKey(lateEveningInLosAngeles, timeZone: TimeZone(identifier: "Europe/Paris")!).string, "2026-11-15")
    }

    func testCodableAsBareString() throws {
        let data = try JSONEncoder().encode([DayKey(year: 2026, month: 11, day: 14)])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["2026-11-14"]"#)
        XCTAssertEqual(try JSONDecoder().decode([DayKey].self, from: data), [DayKey(year: 2026, month: 11, day: 14)])
    }
}
