# Phone a Friend — design

## Intent

A daily nudge to stay in touch with friends. Once a day, a small macOS menu bar app names one friend to text or call. The owner marks whether they reached out. Over time, everyone on the list gets a turn, and whoever has gone longest without contact comes up first.

## Goals

- One suggested friend per day, visible from the menu bar.
- The menu bar icon is visibly colored while today's suggestion is unanswered, and goes back to the normal monochrome icon once it's answered.
- A fair rotation: never-contacted friends first (random order), then longest-since-contact.
- Contacts that happen outside the rotation can be logged so the queue stays honest.

## Non-goals

- No notifications, sounds, or badges beyond the icon color.
- No calling, texting, or opening Messages/FaceTime. The app only names the person.
- No Contacts integration, phone numbers, or notes. A friend is a name.
- No in-app editing of the friend list.
- No sync between Macs, no history view, no streaks or stats.

## Anti-goals

- Nagging. The nudge is the icon color, nothing louder.
- The same friend coming back day after day because they weren't reached.
- Losing contact history when the list file is edited.

## Constraints

- Development happens in a Linux sandbox without Xcode or macOS frameworks. The app is compiled, run and visually checked on the owner's Mac. Anything that can be tested on Linux should be.
- macOS 13+ (SwiftUI `MenuBarExtra`).

## Approaches considered

1. **Native Swift app (chosen).** SwiftUI `MenuBarExtra`, no Dock icon. The queue rules sit in a Foundation-only Swift module unit-tested on Linux; only the thin menu bar layer needs the Mac. Trade-off: UI fixes go back and forth across the sandbox boundary.
2. **SwiftBar plugin.** A single script rendered by the third-party SwiftBar app. Fully testable in the sandbox and has colored icons built in, but it depends on another app and isn't really a Mac app. Rejected because the owner wants a real app.
3. **Electron/Tauri tray app.** Dropped as far too heavy for one menu.

## Behavior

### The friend list

- A plain UTF-8 text file the owner edits by hand: one name per line.
- Leading/trailing whitespace is trimmed. Blank lines and lines starting with `#` are ignored. Duplicate names (exact match after trimming) collapse to one.
- A friend's identity is their name string. Renaming a line makes a new friend.
- History is kept for names removed from the file, but they're never suggested. If a name is added back, its history comes back too.
- The app re-reads the file every minute, at each day rollover and on wake from sleep. It doesn't need to watch the file. SwiftUI's menu bar menu has no reliable "menu opened" hook, so a one-minute timer stands in for one.
- If the file is missing on first launch, the app creates it with a short `#` comment explaining the format.

### Each friend's state

- `lastContacted`: date or none.
- `lastSkipped`: date or none.

### Picking today's friend

1. **Tier 1:** friends never touched (no `lastContacted` and no `lastSkipped`). **Tier 2:** everyone else. Tier 1 is always used before tier 2. (Revised by the owner, 2026-11-14: tier 1 was "never contacted", which made the last never-contacted friend come back every day after Not today.)
2. Within a tier, sort ascending by **last touched** = the later of `lastContacted` and `lastSkipped`, treating "none" as older than any date.
3. Ties, including all never-touched tier-1 friends, are broken at random.
4. Today's friend is the first in that order.

Consequences:

- The first pass through the list is random.
- **Not today** moves a friend to the back of the whole queue without counting as a contact. They come up again after everyone touched before them.
- After the first pass, the order is longest-since-contact.

The pick is made once per day and stored. Reopening the menu or relaunching the app does not re-roll it.

If today's pick is removed from the file **before it's answered**, the app picks again from the current list. Nothing is recorded for the removed friend. The new pick is a fresh, unanswered pick for the same day. If the pick is removed **after it's answered**, the day stays answered and nothing is re-picked; the menu still shows the answered name.

If the list was empty when the day started and names are added later, a pick is made at the next check (menu open, rollover or wake). The icon then turns colored.

### Answering today's suggestion

- **Contacted:** sets `lastContacted = today`.
- **Not today:** sets `lastSkipped = today`. The day counts as answered: the icon goes back to normal, and no replacement is offered until tomorrow.
- Until the day ends, the answer can be changed by clicking the other button (corrects mis-clicks). The current answer shows a checkmark. Changing the answer reverts the previous effect. For example, switching from Contacted to Not today restores the friend's prior `lastContacted`.
  - The day's answer record stores the friend's `lastContacted` and `lastSkipped` from before the day's first answer, so either answer can be reverted exactly.
  - This includes a Contacted made through "Log a contact".
  - Once the day ends, the answer is final. That includes a skip applied at rollover.
- **No answer by the end of the day** is treated as Not today: `lastSkipped` is set to the day the friend was picked.

### Logging other contacts

- A "Log a contact" submenu lists all current friends alphabetically. Clicking one sets their `lastContacted = today`.
- Logging today's pick this way is the same as pressing Contacted.
- Logging anyone else does not answer the day. Today's pick stays pending and the icon stays colored.
- Friends logged today show a checkmark in the submenu. Clicking a checked friend un-logs them, restoring their prior `lastContacted` (corrects mis-clicks). After the day ends, a log is final.

### Day rollover

- Days are local calendar days. Dates are stored as local `yyyy-MM-dd` day keys, not instants.
- "N days ago" is the difference in calendar days.
- Travel across timezones simply changes which day key is "today".
- On rollover, if the stored pick is unanswered, it's resolved as Not today (dated the day it was picked). Then a new pick is made for the new day.
- The app must notice rollover while running, including overnight and after sleep: day-change and wake notifications plus a check whenever the menu opens.
- After several days away, only the one pending pick is resolved as skipped. Missed days are not backfilled.

### Menu bar

```
 ☎ (icon: colored while today is unanswered, monochrome template otherwise)
 ┌──────────────────────────────┐
 │ Today: Sam Rivera            │
 │ Last contact: 47 days ago    │   (or "Never contacted")
 │ ──────────────────────────── │
 │ ✓ Contacted                  │
 │   Not today                  │
 │ ──────────────────────────── │
 │ Log a contact          ▸     │
 │ Edit friend list…            │   (opens friends.txt in the default text editor)
 │ ✓ Open at login              │
 │ Quit                         │
 └──────────────────────────────┘
```

- With an empty list, the top section reads "No friends yet — add names to your list", the icon stays monochrome, and Contacted/Not today are hidden.
- No Dock icon (`LSUIElement`).
- If the list file can't be read, the app keeps using the last list it read successfully and shows a one-line error at the top of the menu. State is never discarded because of a bad read.
- If `state.json` itself can't be used (corrupt, or written by a newer version), it's moved aside to a uniquely named `state.corrupt-<UTC timestamp>.json` and the app starts fresh with a one-line message naming that file. Backups are never overwritten or deleted. A failed save keeps an error line showing and is retried on every refresh until one succeeds.
- If registering for Open at login fails, the toggle shows off and the menu shows a one-line note. Once the owner turns it off, later launches don't re-register it. State records that the first-launch registration already happened.

## Decided by the owner

- Native Swift app (approach 1).
- Hand-edited static text file for the list. Names only.
- No notifications; the icon is colored until the day's suggestion is answered.
- A friend who isn't reached goes back into the queue, and someone new is shown the next day.
- Off-rotation contacts can be logged.
- The app does not dial or message.

## Calls made in writing this up (owner to confirm)

- Ignoring an unanswered day counts as Not today.
- Not today ends the day's nudge (icon back to normal), with no same-day replacement.
- The day's answer can be changed until midnight.
- Skipped friends go to the back of the whole queue via the "last touched" sort (owner ruling, 2026-11-14).
- File locations: `~/Library/Application Support/PhoneAFriend/friends.txt` and `state.json` alongside it, reachable via "Edit friend list…".
- The pending icon color is a fixed orange, not the system accent color.
- Open at login is on by default (registered on first launch via `SMAppService`), with a menu toggle.
- Logging a non-pick friend leaves today pending. Today's logs can be undone from the submenu.
- An unanswered pick removed from the file is re-picked with nothing recorded. An answered pick that's removed keeps the day answered.
- An unreadable list file keeps the last good list.

## Left to the builder

- Project structure. Suggested: a Swift package with a Foundation-only `FriendQueue` library (parsing, state, picking, rollover; clock and random source injected; tested with `swift test` on Linux) and a macOS app target. Package the `.app` with a build script (Info.plist with `LSUIElement`, ad-hoc codesign, copy to `~/Applications`) so there's no hand-written Xcode project.
- State file schema and versioning; atomic writes.
- How the colored icon is drawn: a non-template `NSImage` for the pending state, template otherwise. This is the part most likely to need checking on the Mac.
- The SF Symbol used for the icon.
- Wording of empty and error states, e.g. an unreadable file.
