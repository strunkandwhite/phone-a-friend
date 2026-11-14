import XCTest
@testable import FriendQueue

final class FriendListTests: XCTestCase {
    func testParsesNamesSkippingBlanksAndComments() {
        XCTAssertEqual(FriendList.parse("Sam\n\n# old friends\n  Alex Kim  \n"), ["Sam", "Alex Kim"])
    }

    func testHandlesCRLFAndBOMAndTabs() {
        XCTAssertEqual(FriendList.parse("\u{FEFF}Sam\r\n\tJo\t\r\n"), ["Sam", "Jo"])
    }

    func testDeduplicatesExactMatchesButKeepsCaseVariants() {
        XCTAssertEqual(FriendList.parse("Sam\nsam\nSam \n"), ["Sam", "sam"])
    }

    func testTemplateParsesToEmpty() {
        XCTAssertEqual(FriendList.parse(FriendList.template), [])
    }
}
