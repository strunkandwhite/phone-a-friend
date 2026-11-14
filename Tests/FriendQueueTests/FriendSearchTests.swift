import XCTest
@testable import FriendQueue

final class FriendSearchTests: XCTestCase {
    private let names = ["Rosamund Pike", "Sam Ortiz", "Pam Samuels", "José Ruiz", "Lee"]

    func testBlankQueryShowsNothing() {
        XCTAssertEqual(FriendSearch.results(query: "", names: names), [])
        XCTAssertEqual(FriendSearch.results(query: "   ", names: names), [])
    }

    func testMatchesOnlyFromStartOfWholeName() {
        XCTAssertEqual(FriendSearch.results(query: "sa", names: names), ["Sam Ortiz"])
        XCTAssertEqual(FriendSearch.results(query: "or", names: names), [])
        XCTAssertEqual(FriendSearch.results(query: "r", names: names), ["Rosamund Pike"])
    }

    func testMatchesAreAlphabetical() {
        XCTAssertEqual(FriendSearch.results(query: "s", names: ["Sue", "sam", "Sal"]), ["Sal", "sam", "Sue"])
    }

    func testIgnoresCaseAndAccentsBothWays() {
        XCTAssertEqual(FriendSearch.results(query: "jose", names: names), ["José Ruiz"])
        XCTAssertEqual(FriendSearch.results(query: "JOSÉ", names: ["Jose"]), ["Jose"])
    }

    func testMultiWordQueryMatches() {
        XCTAssertEqual(FriendSearch.results(query: "sam or", names: names), ["Sam Ortiz"])
    }

    func testQueryIsTrimmed() {
        XCTAssertEqual(FriendSearch.results(query: "  lee ", names: names), ["Lee"])
    }

    func testNoMatchesIsEmpty() {
        XCTAssertEqual(FriendSearch.results(query: "zz", names: names), [])
    }
}
