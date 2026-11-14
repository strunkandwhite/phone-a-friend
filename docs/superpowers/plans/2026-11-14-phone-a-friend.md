# Phone a Friend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A macOS menu bar app that suggests one friend to contact each day and keeps a fair rotation.

**Architecture:** One Swift package.
- `FriendQueue` is a Foundation-only library. It holds every rule: list parsing, day keys, picking, answers, rollover and persistence. It is unit-tested on Linux inside the `swift:6.1` Docker image.
- `PhoneAFriend` is a thin SwiftUI `MenuBarExtra` executable that is declared only on macOS. A shell script wraps it into an ad-hoc-signed `.app` bundle.

**Tech Stack:** Swift 5.9 tools / Swift 6.1 toolchain, XCTest, SwiftUI `MenuBarExtra`, AppKit, ServiceManagement (`SMAppService`). No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-11-14-phone-a-friend-design.md`

## Global Constraints

- macOS 13+ (`platforms: [.macOS(.v13)]`). `// swift-tools-version:5.9`. No third-party packages.
- `FriendQueue` imports only Foundation. Nothing in it may reference AppKit, SwiftUI or ServiceManagement.
- Data lives in `~/Library/Application Support/PhoneAFriend/`: `friends.txt` (hand-edited) and `state.json` (app-owned).
- Days are local calendar days, stored as `yyyy-MM-dd` strings (`DayKey`), never as instants.
- `friends.txt` is never committed (already in `.gitignore`).
- Pending icon color: `NSColor.systemOrange`. Otherwise the icon is a monochrome template image.
- Exact menu copy:
  - `Today: <name>`
  - `Never contacted` / `Last contact: today` / `Last contact: yesterday` / `Last contact: N days ago`
  - `Contacted`, `Not today`, `Log a contact`, `Edit friend list…`, `Open at login`, `Quit`
  - `No friends yet — add names to your list`
- Linux test command for every task: `scripts/test-linux.sh` (created in Task 1). In-sandbox git commands use `git -C /Users/arpanet/code/phone-a-friend`. Work on `main`, with no worktrees. Commit messages say why and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **The clock goes backwards**, e.g. flying west across midnight puts `today` before the stored pick's day. Expected: keep the existing pick as current. Don't resolve it, don't re-roll it, don't crash. Test in Task 3.
2. **A corrupt or newer-version `state.json`.** Expected: don't crash and don't silently wipe history. Move the file aside to `state.corrupt.json`, start fresh, and surface a one-line error. Test in Task 4.
3. **Messy list text:** Windows `\r\n` line endings, a UTF-8 BOM, tabs and spaces around names, and case variants ("Sam" vs "sam"). Expected: `\r` and BOM stripped, names trimmed, case-sensitive identity. Test in Task 1.
4. **A one-friend list.** Expected: that friend is suggested every day, even right after Not today. Test in Task 2.
5. **The app is off for weeks.** Expected: exactly one skip is recorded (dated the stale pick's day), old-day logs become final, and a fresh pick is made for today. Test in Task 3.

---

### Task 1: Package scaffold, `DayKey`, list parsing, Linux test runner

**Files:**
- Create: `Package.swift`, `scripts/test-linux.sh`, `Sources/FriendQueue/DayKey.swift`, `Sources/FriendQueue/FriendList.swift`
- Create: `Tests/FriendQueueTests/DayKeyTests.swift`, `Tests/FriendQueueTests/FriendListTests.swift`
- Modify: `.gitignore` (add `.build-linux/`)

**Interfaces:**
- Produces:
  - `public struct DayKey: Hashable, Comparable, Codable, CustomStringConvertible`. It encodes as a single `"yyyy-MM-dd"` string. Members:
    - `init(year: Int, month: Int, day: Int)`
    - `init(_ date: Date, calendar: Calendar = .current)`
    - `init?(string: String)`
    - `var string: String`
    - `func days(since earlier: DayKey) -> Int` (calendar-day difference; negative if `earlier` is later)
  - `public enum FriendList`:
    - `static func parse(_ text: String) -> [String]` (file order, deduplicated, first occurrence wins)
    - `static let template: String`

- [ ] **Step 1: Create `Package.swift` and the runner.**
  - The manifest declares only the `FriendQueue` library target and the `FriendQueueTests` test target, with `platforms: [.macOS(.v13)]`. The app target comes in Task 5.
  - `scripts/test-linux.sh` (mark it executable) runs:
    `docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$repo:/src" -w /src swift:6.1 swift test --scratch-path .build-linux "$@"`
    Here `$repo` is the script's parent directory. The separate scratch path keeps Linux build products away from the Mac's `.build/`.
  - Add `.build-linux/` to `.gitignore`.

- [ ] **Step 2: Write the failing tests.**

```swift
// DayKeyTests
func testStringRoundTrip() { XCTAssertEqual(DayKey(string: "2026-03-07")?.string, "2026-03-07") }
func testRejectsGarbage() { XCTAssertNil(DayKey(string: "2026-3-7x")) }
func testOrdering() { XCTAssertLessThan(DayKey(year: 2026, month: 12, day: 31), DayKey(year: 2027, month: 1, day: 1)) }
func testDaysSinceAcrossYearAndDST() {
    XCTAssertEqual(DayKey(year: 2027, month: 1, day: 2).days(since: DayKey(year: 2026, month: 12, day: 30)), 3)
    XCTAssertEqual(DayKey(year: 2026, month: 3, day: 9).days(since: DayKey(year: 2026, month: 3, day: 7)), 2)
    XCTAssertEqual(DayKey(year: 2026, month: 1, day: 1).days(since: DayKey(year: 2026, month: 1, day: 3)), -2)
}
func testFromDateUsesGivenCalendarTimeZone() {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    let date = ISO8601DateFormatter().date(from: "2026-11-15T06:30:00Z")!   // 22:30 on the 14th in LA
    XCTAssertEqual(DayKey(date, calendar: cal).string, "2026-11-14")
}
func testCodableAsBareString() throws {
    let data = try JSONEncoder().encode([DayKey(year: 2026, month: 11, day: 14)])
    XCTAssertEqual(String(decoding: data, as: UTF8.self), #"["2026-11-14"]"#)
}

// FriendListTests
func testParsesNamesSkippingBlanksAndComments() {
    XCTAssertEqual(FriendList.parse("Sam\n\n# old friends\n  Alex Kim  \n"), ["Sam", "Alex Kim"])
}
func testHandlesCRLFAndBOMAndTabs() {
    XCTAssertEqual(FriendList.parse("\u{FEFF}Sam\r\n\tJo\t\r\n"), ["Sam", "Jo"])
}
func testDeduplicatesExactMatchesButKeepsCaseVariants() {
    XCTAssertEqual(FriendList.parse("Sam\nsam\nSam \n"), ["Sam", "sam"])
}
func testTemplateParsesToEmpty() { XCTAssertEqual(FriendList.parse(FriendList.template), []) }
```

- [ ] **Step 3: Run `scripts/test-linux.sh`.** Expected: a compile failure (`DayKey` and `FriendList` are undefined).

- [ ] **Step 4: Implement `DayKey` and `FriendList`.**
  - `DayKey` stores `year`, `month` and `day`. `days(since:)` converts both to midnight `Date`s in a fixed gregorian UTC calendar and takes the `.day` difference, so DST can't skew it.
  - `Comparable` compares `(year, month, day)`.
  - `template` is exactly:
    ```
    # Phone a Friend — one name per line.
    # Blank lines and lines starting with # are ignored.
    ```

- [ ] **Step 5: Run `scripts/test-linux.sh`.** Expected: all tests pass.

- [ ] **Step 6: Commit** `Package.swift`, `scripts/`, `Sources/`, `Tests/` and `.gitignore`. Message: "Scaffold the Linux-testable queue library so the rotation rules can be verified without a Mac."

### Task 2: Friend records and the picking rule

**Files:**
- Create: `Sources/FriendQueue/AppState.swift`, `Sources/FriendQueue/Picker.swift`
- Create: `Tests/FriendQueueTests/PickerTests.swift`, `Tests/FriendQueueTests/SeededGenerator.swift` (SplitMix64 `RandomNumberGenerator`, `init(seed: UInt64)`)

**Interfaces:**
- Consumes: `DayKey`.
- Produces:
  - `public struct FriendRecord: Codable, Equatable`:
    - `var lastContacted: DayKey?`
    - `var lastSkipped: DayKey?`
    - `var lastTouched: DayKey?` (the later of the two, or nil)
    - `init(lastContacted: DayKey? = nil, lastSkipped: DayKey? = nil)`
  - `public enum Answer: String, Codable { case contacted, skipped }`
  - `public struct DailyPick: Codable, Equatable`:
    - `var day: DayKey`
    - `var friend: String`
    - `var answer: Answer?`
    - `var priorRecord: FriendRecord` (the friend's record when the pick was made)
  - `public struct AppState: Codable, Equatable`:
    - `static let currentVersion = 1`
    - `var version = 1`
    - `var friends: [String: FriendRecord] = [:]`
    - `var pick: DailyPick? = nil`
    - `var logDay: DayKey? = nil`
    - `var logPriors: [String: FriendRecord] = [:]`
    - `var loginItemInitialized = false`
    - `public init()`
  - `public enum Picker { static func choose<G: RandomNumberGenerator>(from names: [String], records: [String: FriendRecord], using rng: inout G) -> String? }`

- [ ] **Step 1: Write the failing tests.** `d(n)` is a test helper for `DayKey(year: 2026, month: 1, day: n)`.

```swift
func testEmptyListPicksNobody() { var g = SeededGenerator(seed: 1); XCTAssertNil(Picker.choose(from: [], records: [:], using: &g)) }
func testNeverContactedTierBeatsLongAgoContact() {
    var g = SeededGenerator(seed: 1)
    let records = ["Old": FriendRecord(lastContacted: d(1)), "New": FriendRecord(lastSkipped: d(20))]
    XCTAssertEqual(Picker.choose(from: ["Old", "New"], records: records, using: &g), "New")
}
func testWithinTierOldestLastTouchedWins() {
    var g = SeededGenerator(seed: 1)
    let records = ["A": FriendRecord(lastContacted: d(5)), "B": FriendRecord(lastContacted: d(2)), "C": FriendRecord(lastContacted: d(9))]
    XCTAssertEqual(Picker.choose(from: ["A", "B", "C"], records: records, using: &g), "B")
}
func testSkipCountsAsTouchedButNotContacted() {
    var g = SeededGenerator(seed: 1)
    // B was contacted earliest but skipped most recently, so A wins.
    let records = ["A": FriendRecord(lastContacted: d(3)), "B": FriendRecord(lastContacted: d(1), lastSkipped: d(10))]
    XCTAssertEqual(Picker.choose(from: ["A", "B"], records: records, using: &g), "A")
}
func testNeverTouchedComesBeforeSkippedInTierOne() {
    var g = SeededGenerator(seed: 1)
    XCTAssertEqual(Picker.choose(from: ["Skipped", "Fresh"], records: ["Skipped": FriendRecord(lastSkipped: d(4))], using: &g), "Fresh")
}
func testTiesAreBrokenRandomly() {
    let firsts = Set((0..<50).map { seed -> String in var g = SeededGenerator(seed: UInt64(seed)); return Picker.choose(from: ["A", "B", "C"], records: [:], using: &g)! })
    XCTAssertEqual(firsts, ["A", "B", "C"])
}
func testRecordsForRemovedNamesAreIgnored() {
    var g = SeededGenerator(seed: 1)
    XCTAssertEqual(Picker.choose(from: ["A"], records: ["Gone": FriendRecord(), "A": FriendRecord(lastContacted: d(1))], using: &g), "A")
}
func testSingleFriendIsAlwaysPicked() {   // Review Focus 4
    var g = SeededGenerator(seed: 1)
    XCTAssertEqual(Picker.choose(from: ["Solo"], records: ["Solo": FriendRecord(lastContacted: d(1), lastSkipped: d(2))], using: &g), "Solo")
}
```

- [ ] **Step 2: Run `scripts/test-linux.sh --filter PickerTests`.** Expected: a compile failure.

- [ ] **Step 3: Implement the types and the picking rule.**
  - Picking: tier = `lastContacted == nil ? 0 : 1`. Sort key = `(tier, lastTouched)`, where a nil `lastTouched` sorts before any day. Shuffle the minimal-key candidates with `rng` and take the first.
  - Shuffle only the tied minimum, so the result is deterministic for a given seed.

- [ ] **Step 4: Run `scripts/test-linux.sh`.** Expected: all tests pass.

- [ ] **Step 5: Commit.** Message: "Encode the rotation: never-contacted first, then longest since last touch, with Not today pushing to the back of its tier."

### Task 3: Daily engine — picking, answering, logging, rollover

**Files:**
- Create: `Sources/FriendQueue/DailyEngine.swift` (an `extension AppState`)
- Create: `Tests/FriendQueueTests/DailyEngineTests.swift`

**Interfaces:**
- Consumes: everything from Task 2.
- Produces (all on `AppState`):
  - `mutating func refresh<G: RandomNumberGenerator>(names: [String], today: DayKey, using rng: inout G)`
  - `mutating func setAnswer(_ answer: Answer?, today: DayKey)` (nil means unanswered)
  - `mutating func toggleLog(_ name: String, today: DayKey)`
  - `var isPending: Bool` (a pick exists and is unanswered)
  - `func loggedToday(_ today: DayKey) -> Set<String>`

`refresh` runs in this order:
1. **Rollover.** If `pick.day < today`: when it's unanswered and `names` still contains its friend, set that friend's `lastSkipped = pick.day`. Then set `pick = nil`. A pick dated after `today` stays put (Review Focus 1).
2. **Expire logs.** If `logDay != nil && logDay! < today`, clear `logDay` and `logPriors`. Those logs are now final.
3. **Removed pick.** If the pick is unanswered and its friend isn't in `names`, set `pick = nil` and record nothing. An answered pick is kept even if removed.
4. **New pick.** If `pick == nil`, pick with `Picker.choose`. Use the new pick's `priorRecord = friends[name] ?? FriendRecord()`.

`setAnswer`:
- Restore `friends[pick.friend] = pick.priorRecord`.
- Then apply: `.contacted` sets `lastContacted = pick.day`; `.skipped` sets `lastSkipped = pick.day`.
- Store the answer.
- Does nothing when there's no pick.

`toggleLog`:
- **The name is today's pick:** call `setAnswer(pick.answer == .contacted ? nil : .contacted)`.
- **Anyone else, already logged today:** restore `friends[name] = logPriors[name]` and remove the entry.
- **Anyone else, not yet logged today:** record the prior record, set `lastContacted = today`, and set `logDay = today`.

`loggedToday` returns the `logPriors` keys when `logDay == today`, plus the pick's friend when its answer is `.contacted`.

- [ ] **Step 1: Write the failing tests.**
  - Helper: `func refreshed(_ s: inout AppState, _ names: [String], _ today: DayKey, seed: UInt64 = 1)`.
  - Each test name below is followed by the assertions it makes.

```swift
testFirstRefreshPicksAndIsPending              // pick?.day == today, isPending == true
testRefreshSameDayDoesNotReroll                // refresh twice with different seeds → same pick.friend
testEmptyListHasNoPickAndIsNotPending          // pick == nil, isPending == false
testNamesAddedMidDayGetAPick                   // refresh([]) then refresh(["A"]) same day → pick?.friend == "A", isPending
testContactedSetsLastContactedAndClearsPending // friends["A"]?.lastContacted == today, isPending == false
testNotTodaySetsLastSkippedAndClearsPending    // friends["A"]?.lastSkipped == today, lastContacted == nil, isPending == false
testChangingAnswerRevertsPreviousEffect        // A had lastContacted d(1); contacted then skipped → lastContacted == d(1), lastSkipped == today
testUnansweringRestoresPriorRecord             // setAnswer(.contacted) then setAnswer(nil) → friends["A"] == priorRecord, isPending
testUnansweredPickBecomesSkipAtRollover        // pick on d(5), refresh on d(6) → friends[old].lastSkipped == d(5), new pick dated d(6)
testAnsweredPickIsFinalAfterRollover           // contacted on d(5), refresh d(6), setAnswer(.skipped) → old friend's lastContacted still d(5)
testWeeksAwayRecordsOneSkipOnly                // Review Focus 5: pick d(5), refresh d(30) → old.lastSkipped == d(5); logDay == nil; pick.day == d(30)
testNextDayShowsSomeoneNewAfterNotToday        // ["A","B"]: day 5 skip → day 6 pick is the other one
testRemovedUnansweredPickIsRepickedWithNothingRecorded // remove pick's name same day → new friend; friends[old] unchanged
testRemovedAnsweredPickKeepsDayAnswered        // answered, then refresh without that name → pick unchanged, isPending == false
testRemovedPickNotSkippedAtRollover            // unanswered pick removed overnight → no lastSkipped for it
testClockGoingBackwardsKeepsPick               // Review Focus 1: pick d(10), refresh d(9) → pick unchanged, nothing recorded
testLoggingOtherFriendLeavesPickPending        // toggleLog("B") → B.lastContacted == today, isPending == true, loggedToday == ["B"]
testLoggingTwiceUndoesLog                      // toggleLog("B") ×2 → friends["B"] == prior, loggedToday empty
testLoggingTodaysPickEqualsContacted           // toggleLog(pick) → pick.answer == .contacted; again → answer nil, record restored
testLogsBecomeFinalNextDay                     // log B on d(5), refresh d(6), toggleLog("B") → treated as new log (prior = record with lastContacted d(5))
testFullRotationVisitsEveryoneBeforeRepeating  // 4 names, contact each day for 4 days → 4 distinct picks; day 5 picks day 1's friend
```

- [ ] **Step 2: Run `scripts/test-linux.sh --filter DailyEngineTests`.** Expected: a compile failure.

- [ ] **Step 3: Implement `DailyEngine.swift`** with the signatures and orderings above.

- [ ] **Step 4: Run `scripts/test-linux.sh`.** Expected: all tests pass.

- [ ] **Step 5: Commit.** Message: "Add the daily lifecycle so unanswered days roll over as skips and mis-clicks can be undone until midnight."

### Task 4: Persistence, last-good list, display text

**Files:**
- Create: `Sources/FriendQueue/StateStore.swift`, `Sources/FriendQueue/FriendListLoader.swift`, `Sources/FriendQueue/DisplayText.swift`
- Modify: `Sources/FriendQueue/AppState.swift` (custom `init(from:)`)
- Create: `Tests/FriendQueueTests/StateStoreTests.swift`, `Tests/FriendQueueTests/DisplayTextTests.swift`
- Tests use a fresh temp directory per test (`FileManager.default.temporaryDirectory/UUID`).

**Interfaces:**
- Consumes: `AppState`, `FriendList`, `DayKey`, `FriendRecord`.
- Produces:
  - `public struct StateStore`:
    - `init(directory: URL)`
    - `static func defaultDirectory() -> URL` (`applicationSupportDirectory/PhoneAFriend`)
    - `var friendsURL: URL`, `var stateURL: URL`
    - `func ensureFriendListExists() throws` (creates the directory, and writes `FriendList.template` only if the file is missing)
    - `func readFriendNames() throws -> [String]`
    - `func loadState() -> StateLoad`
    - `func save(_ state: AppState) throws` (atomic write, pretty-printed, sorted keys)
  - `public enum StateLoad: Equatable { case loaded(AppState), fresh, recovered(AppState, movedTo: URL) }`
    - `fresh` means there's no file.
    - `recovered` means the file was unreadable, undecodable or had `version > currentVersion`. It was renamed to `state.corrupt.json`, replacing any older one, and a new `AppState()` is returned.
  - `public struct FriendListLoader`:
    - `private(set) var lastGood: [String] = []`
    - `private(set) var error: String?`
    - `mutating func reload(from store: StateStore) -> [String]`
    - On a read failure, it returns `lastGood` and sets `error = "Couldn't read friends.txt — using the last list."`. On success, it clears `error`.
  - `public enum DisplayText`:
    - `static func lastContact(_ record: FriendRecord?, today: DayKey) -> String`
    - Strings, per Global Constraints: `Never contacted` / `Last contact: today` / `Last contact: yesterday` / `Last contact: N days ago`. A negative difference reads as `today`.

- [ ] **Step 1: Write the failing tests.**

```swift
testEnsureFriendListCreatesTemplateOnce   // write "Sam\n" after first ensure, ensure again → file still "Sam\n"
testReadFriendNamesParses                  // "Sam\n# x\nJo" → ["Sam", "Jo"]
testLoadWithNoFileIsFresh                  // == .fresh
testSaveThenLoadRoundTrips                 // state with records, pick, logPriors → .loaded(equal state)
testCorruptStateIsMovedAsideNotDeleted     // Review Focus 2: write "{nope" → .recovered(AppState(), movedTo: state.corrupt.json); that file's contents == "{nope"; state.json gone
testNewerVersionStateIsMovedAside          // {"version": 99, ...} → .recovered
testLoaderKeepsLastGoodListOnReadFailure   // reload ok (["Sam"]), then make friends.txt a directory → returns ["Sam"], error non-nil; fix → error nil
testLastContactStrings                     // nil → "Never contacted"; same day → "Last contact: today"; 1 → "Last contact: yesterday"; 47 → "Last contact: 47 days ago"; future → "Last contact: today"
```

- [ ] **Step 2: Run `scripts/test-linux.sh --filter "StateStoreTests|DisplayTextTests"`.** Expected: a compile failure.

- [ ] **Step 3: Implement the three files.**
  - Decoding must tolerate missing optional keys, so older state files still load. Give `AppState` a custom `init(from:)` with `decodeIfPresent` defaults.

- [ ] **Step 4: Run `scripts/test-linux.sh`.** Expected: all tests pass.

- [ ] **Step 5: Commit.** Message: "Persist state atomically and never discard history on a bad read of either file."

### Task 5: macOS menu bar app, bundle script, README

This task can't be compiled in the sandbox. The implementer writes it carefully against the APIs named here, confirms the Linux tests still pass, and hands the Mac checklist (Step 4) to the owner.

**Files:**
- Modify: `Package.swift`. Inside `#if os(macOS)`, append `.executableTarget(name: "PhoneAFriend", dependencies: ["FriendQueue"])` and `.executable(name: "PhoneAFriend", targets: ["PhoneAFriend"])`.
- Create: `Sources/PhoneAFriend/PhoneAFriendApp.swift`, `Sources/PhoneAFriend/AppModel.swift`, `Sources/PhoneAFriend/MenuContent.swift`, `Sources/PhoneAFriend/StatusIcon.swift`, `Sources/PhoneAFriend/LoginItem.swift`
- Create: `App/Info.plist`, `scripts/build-app.sh`, `README.md`

**Interfaces:**
- Consumes: `StateStore`, `StateLoad`, `FriendListLoader`, `AppState` (`refresh`, `setAnswer`, `toggleLog`, `isPending`, `loggedToday`, `loginItemInitialized`), `DayKey(Date())`, `DisplayText.lastContact`.
- Produces:
  - `@MainActor final class AppModel: ObservableObject`:
    - `@Published private(set) var state: AppState`
    - `@Published private(set) var names: [String]`
    - `@Published private(set) var errorLine: String?`
    - `func refresh()`, `func answer(_: Answer?)`, `func toggleLog(_: String)`, `func openFriendList()`, `func setOpenAtLogin(_: Bool)`
    - `var openAtLogin: Bool`
    - Every mutation saves via `StateStore` and republishes.

- [ ] **Step 1: Write the app.**
  - **`PhoneAFriendApp`:** `@main`. `MenuBarExtra { MenuContent(model:) } label: { StatusIcon(pending: model.state.isPending) }` with `.menuBarExtraStyle(.menu)`.
  - **`AppModel.init`:**
    - Call `ensureFriendListExists`, then `loadState`. If the result is `.recovered`, set `errorLine = "State file was unreadable — saved a copy as state.corrupt.json."`.
    - Run the first-launch login registration (below), then `refresh()`.
    - Call `refresh()` on `NSNotification.Name.NSCalendarDayChanged`, on `NSWorkspace.didWakeNotification` (via `NSWorkspace.shared.notificationCenter`), and on a 60-second `Timer`. The timer stands in for "re-read when the menu opens", because `MenuBarExtra`'s menu style has no reliable open hook.
  - **`refresh()`:** `names = loader.reload(from:)`, then `state.refresh(names:today:using:)` with a local `SystemRandomNumberGenerator()`, then save. `errorLine` shows the loader's error or the recovery message.
  - **`StatusIcon`:**
    - Symbol: `person.wave.2.fill`.
    - Pending: an `NSImage` with `NSImage.SymbolConfiguration(paletteColors: [.systemOrange])` and `isTemplate = false`.
    - Otherwise: the same symbol with `isTemplate = true`.
    - Render with `Image(nsImage:)`.
  - **`MenuContent`**, in order (checkmark items are `Toggle`s, which the menu style renders with checkmarks):
    1. `errorLine`, if any, as disabled text.
    2. If there's no pick: the disabled text `No friends yet — add names to your list`. Otherwise, disabled `Today: <friend>` and `DisplayText.lastContact(pick.priorRecord, today:)`.
       - Use `priorRecord`, so answering Contacted doesn't flip the line to "today" mid-day.
    3. A divider, then `Toggle("Contacted")` and `Toggle("Not today")`, bound to `pick.answer`. Turning a checked one off means `answer(nil)`. Hidden when there's no pick.
    4. A divider, then `Menu("Log a contact")` with one `Toggle` per name, sorted alphabetically with `localizedStandardCompare`, checked when the name is in `loggedToday`.
    5. `Button("Edit friend list…")` → `NSWorkspace.shared.open(store.friendsURL)`.
    6. `Toggle("Open at login")`, plus a disabled note `Couldn't turn on Open at login` if the last register call threw.
    7. `Button("Quit")` → `NSApplication.shared.terminate(nil)`.
  - **`LoginItem`:**
    - Wraps `SMAppService.mainApp`: `isEnabled` (`status == .enabled`), `register()`, `unregister()`.
    - First launch: if `!state.loginItemInitialized`, try `register()` and set the flag to true whether or not it succeeds, then save. Later launches never auto-register.
  - **`App/Info.plist`:**
    - `CFBundleExecutable` = `PhoneAFriend`
    - `CFBundleIdentifier` = `com.strunkandwhite.phone-a-friend`
    - `CFBundleName` = `Phone a Friend`
    - `CFBundlePackageType` = `APPL`
    - `CFBundleShortVersionString` = `1.0`
    - `LSMinimumSystemVersion` = `13.0`
    - `LSUIElement` = true
  - **`scripts/build-app.sh [--install]`** (`set -euo pipefail`):
    1. `swift build -c release --product PhoneAFriend`.
    2. Assemble `build/PhoneAFriend.app/Contents/{MacOS/PhoneAFriend,Info.plist}` from `swift build -c release --show-bin-path`.
    3. `codesign --force --sign - build/PhoneAFriend.app`.
    4. With `--install`: `pkill -x PhoneAFriend || true`, replace `~/Applications/PhoneAFriend.app`, then `open` it.
  - **`README.md`:** what the app does (two sentences), `scripts/build-app.sh --install` on a Mac, `scripts/test-linux.sh` for the rules, and where the data files live.

- [ ] **Step 2: Run `scripts/test-linux.sh`.** Expected: all tests still pass. The `#if os(macOS)` manifest guard keeps the app target out of the Linux build.

- [ ] **Step 3: Commit.** Message: "Add the menu bar app and bundle script; the app layer stays thin so the tested library carries the rules."

- [ ] **Step 4: Owner verification on the Mac.** Hand the owner this checklist, and fix anything that fails in follow-up commits.
  1. `scripts/build-app.sh --install` builds with no errors, and the app appears in the menu bar with no Dock icon.
  2. `Edit friend list…` opens `friends.txt` showing the template. Add three names and save. Within a minute the icon turns **orange** and the menu shows `Today: <name>` and `Never contacted`.
  3. Click `Contacted`: the icon returns to monochrome and adapts to a light and a dark menu bar. Click `Not today`: the checkmark moves.
  4. `Log a contact` → another name: the checkmark appears and the icon is unchanged. Click it again: the checkmark is gone.
  5. Quit and relaunch: the same pick and answer.
  6. `Open at login` is checked after first launch. Uncheck it, quit and relaunch: it stays unchecked.
