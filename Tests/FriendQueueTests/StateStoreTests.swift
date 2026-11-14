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

    private let recoveryTime = ISO8601DateFormatter().date(from: "2026-11-14T09:30:05Z")!

    func testCorruptStateIsMovedAsideNotDeleted() throws {
        try write("{nope", to: store.stateURL)
        let backupURL = directory.appendingPathComponent("state.corrupt-20261114-093005.json")
        XCTAssertEqual(store.loadState(now: recoveryTime), .recovered(AppState(), movedTo: backupURL))
        XCTAssertEqual(try contents(of: backupURL), "{nope")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.stateURL.path))
    }

    func testSecondCorruptionKeepsFirstBackup() throws {
        try write("first junk", to: store.stateURL)
        guard case let .recovered(_, firstBackup) = store.loadState(now: recoveryTime) else {
            return XCTFail("expected recovery")
        }
        try write("second junk", to: store.stateURL)
        guard case let .recovered(_, secondBackup) = store.loadState(now: recoveryTime) else {
            return XCTFail("expected recovery")
        }
        XCTAssertNotEqual(firstBackup, secondBackup)
        XCTAssertEqual(try contents(of: firstBackup), "first junk")
        XCTAssertEqual(try contents(of: secondBackup), "second junk")
    }

    func testNewerVersionStateIsMovedAsideIntact() throws {
        let newer = #"{"version": 99, "friends": {}}"#
        try write(newer, to: store.stateURL)
        guard case let .recovered(_, backup) = store.loadState(now: recoveryTime) else {
            return XCTFail("expected a newer-version state file to be set aside")
        }
        XCTAssertEqual(try contents(of: backup), newer)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.stateURL.path))
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
