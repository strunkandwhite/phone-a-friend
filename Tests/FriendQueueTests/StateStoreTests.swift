import Foundation
import XCTest
@testable import FriendQueue

final class StateStoreTests: XCTestCase {
    private var directory: URL!
    private var store: StateStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = StateStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func contents(of url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func testEnsureFriendListCreatesTemplateOnce() throws {
        try store.ensureFriendListExists()
        XCTAssertEqual(try contents(of: store.friendsURL), FriendList.template)
        try write("Sam\n", to: store.friendsURL)
        try store.ensureFriendListExists()
        XCTAssertEqual(try contents(of: store.friendsURL), "Sam\n")
    }

    func testReadFriendNamesParses() throws {
        try write("Sam\n# x\nJo", to: store.friendsURL)
        XCTAssertEqual(try store.readFriendNames(), ["Sam", "Jo"])
    }

    func testLoadWithNoFileIsFresh() {
        XCTAssertEqual(store.loadState(), .fresh)
    }

    func testSaveThenLoadRoundTrips() throws {
        var state = AppState()
        state.friends = ["Sam": FriendRecord(lastContacted: d(1)), "Jo": FriendRecord(lastSkipped: d(2))]
        state.pick = DailyPick(day: d(3), friend: "Jo", answer: .skipped, priorRecord: FriendRecord())
        state.logDay = d(3)
        state.logPriors = ["Sam": FriendRecord()]
        state.loginItemInitialized = true
        try store.save(state)
        XCTAssertEqual(store.loadState(), .loaded(state))
    }

    func testOlderStateWithMissingKeysLoads() throws {
        try write(#"{"version": 1, "friends": {"Sam": {"lastContacted": "2026-01-01"}}}"#, to: store.stateURL)
        var expected = AppState()
        expected.friends = ["Sam": FriendRecord(lastContacted: d(1))]
        XCTAssertEqual(store.loadState(), .loaded(expected))
    }

    func testCorruptStateIsMovedAsideNotDeleted() throws {
        try write("{nope", to: store.stateURL)
        let corruptURL = directory.appendingPathComponent("state.corrupt.json")
        XCTAssertEqual(store.loadState(), .recovered(AppState(), movedTo: corruptURL))
        XCTAssertEqual(try contents(of: corruptURL), "{nope")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.stateURL.path))
    }

    func testCorruptStateReplacesOlderCorruptCopy() throws {
        let corruptURL = directory.appendingPathComponent("state.corrupt.json")
        try write("old junk", to: corruptURL)
        try write("new junk", to: store.stateURL)
        XCTAssertEqual(store.loadState(), .recovered(AppState(), movedTo: corruptURL))
        XCTAssertEqual(try contents(of: corruptURL), "new junk")
    }

    func testNewerVersionStateIsMovedAside() throws {
        try write(#"{"version": 99, "friends": {}}"#, to: store.stateURL)
        guard case .recovered = store.loadState() else {
            return XCTFail("expected a newer-version state file to be set aside")
        }
    }

    func testLoaderReportsNoListBeforeFirstSuccessfulRead() throws {
        var loader = FriendListLoader()
        try FileManager.default.createDirectory(at: store.friendsURL, withIntermediateDirectories: true)
        XCTAssertNil(loader.reload(from: store))
        XCTAssertEqual(loader.error, "Couldn't read friends.txt — using the last list.")
    }

    func testLoaderKeepsLastGoodListOnReadFailure() throws {
        var loader = FriendListLoader()
        try write("Sam\n", to: store.friendsURL)
        XCTAssertEqual(loader.reload(from: store), ["Sam"])
        XCTAssertNil(loader.error)

        try FileManager.default.removeItem(at: store.friendsURL)
        try FileManager.default.createDirectory(at: store.friendsURL, withIntermediateDirectories: false)
        XCTAssertEqual(loader.reload(from: store), ["Sam"])
        XCTAssertEqual(loader.error, "Couldn't read friends.txt — using the last list.")

        try FileManager.default.removeItem(at: store.friendsURL)
        try write("Jo\n", to: store.friendsURL)
        XCTAssertEqual(loader.reload(from: store), ["Jo"])
        XCTAssertNil(loader.error)
    }
}
