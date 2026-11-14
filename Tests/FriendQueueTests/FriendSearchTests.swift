import XCTest
@testable import FriendQueue

final class FriendSearchTests: XCTestCase {
    private let names = ["Rosamund Pike", "Sam Ortiz", "Pam Samuels", "José Ruiz", "Lee"]

    func testEmptyQueryShowsOnlyLoggedToday() {
        XCTAssertEqual(FriendSearch.results(query: "", names: names, loggedToday: ["Sam Ortiz", "Lee"]), ["Lee", "Sam Ortiz"])
    }

    func testWhitespaceQueryActsEmpty() {
        XCTAssertEqual(FriendSearch.results(query: "   ", names: names, loggedToday: ["Lee"]), ["Lee"])
    }

    func testEmptyQueryNoLogsIsEmpty() {
        XCTAssertEqual(FriendSearch.results(query: "", names: names, loggedToday: []), [])
    }

    func testLoggedButRemovedNameIsNotShown() {
        XCTAssertEqual(FriendSearch.results(query: "", names: ["Lee"], loggedToday: ["Gone", "Lee"]), ["Lee"])
    }

    func testWordStartRanksAboveContains() {
        XCTAssertEqual(FriendSearch.results(query: "sam", names: names, loggedToday: []), ["Pam Samuels", "Sam Ortiz", "Rosamund Pike"])
    }

    func testIgnoresCaseAndAccentsBothWays() {
        XCTAssertEqual(FriendSearch.results(query: "jose", names: names, loggedToday: []), ["José Ruiz"])
        XCTAssertEqual(FriendSearch.results(query: "JOSÉ", names: ["Jose"], loggedToday: []), ["Jose"])
    }

    func testMultiWordQueryMatches() {
        XCTAssertEqual(FriendSearch.results(query: "sam or", names: names, loggedToday: []), ["Sam Ortiz"])
    }

    func testQueryIsTrimmed() {
        XCTAssertEqual(FriendSearch.results(query: "  lee ", names: names, loggedToday: []), ["Lee"])
    }

    func testReturnTargetIsNilForBlankQueryEvenWithLogs() {
        XCTAssertNil(FriendSearch.returnTarget(query: "", names: names, loggedToday: ["Lee"]))
        XCTAssertNil(FriendSearch.returnTarget(query: "   ", names: names, loggedToday: ["Lee"]))
    }

    func testReturnTargetIsTopMatch() {
        XCTAssertEqual(FriendSearch.returnTarget(query: "sam", names: names, loggedToday: []), "Pam Samuels")
        XCTAssertNil(FriendSearch.returnTarget(query: "zz", names: names, loggedToday: []))
    }

    func testNoMatchesIsEmpty() {
        XCTAssertEqual(FriendSearch.results(query: "zz", names: names, loggedToday: []), [])
    }
}
