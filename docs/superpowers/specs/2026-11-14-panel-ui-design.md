# Phone a Friend — panel UI (amends the original design)

Amends `2026-11-14-phone-a-friend-design.md`. Every rule in that document — picking, answering, logging, rollover, persistence — is unchanged. This replaces only its **Menu bar** section and the icon.

## Why

After running the first build, the owner found three problems:
- Today's friend is the point of the app, but as a disabled menu row it doesn't stand out.
- "Log a contact" as a submenu doesn't scale to a long list. It needs type-to-search.
- The icon should be a phone.

A standard menu can't hold a text field, so the menu becomes a small panel.

## Approaches

- **A. Panel (chosen by the owner).** `MenuBarExtra` with `.menuBarExtraStyle(.window)`: a small panel under the icon, built from ordinary SwiftUI views. Today's friend is the headline, the answers are real buttons, and search is a text field. The panel can also refresh when it opens. The cost is a less native look and layout that has to be checked on the Mac.
- **B. Keep the menu.** Today's friend becomes a submenu holding Contacted and Not today. "Log a contact…" opens a separate search window. Rejected: today's friend is still just a menu row, and there would be two UIs to maintain.

## Icon

- SF Symbol `phone.fill`.
- Orange while today is unanswered; otherwise a monochrome template image. This is the same mechanism as before; only the symbol changes.

## Panel layout

About 300pt wide:

```
┌──────────────────────────────────┐
│ (error line, if any)             │
│ TODAY                            │
│ Sam Rivera                       │
│ Last contact: 47 days ago        │
│ [ Contacted ]   [ Not today ]    │
├──────────────────────────────────┤
│ Log a contact                    │
│ [ Type a name…               ]   │
│   Samantha Lee                   │
│   Sam Ortiz             ✓ today  │
├──────────────────────────────────┤
│ Edit list…  ☑ Open at login  Quit│
└──────────────────────────────────┘
```

### Today

- The caption "TODAY" is small and secondary.
- The friend's name is large and bold (title-sized).
- "Last contact: …" uses the existing text and shows the record from before today's answer.
- **Contacted** is the prominent button and **Not today** the secondary one.
  - The chosen answer shows a checkmark ("✓ Contacted").
  - Clicking the chosen answer again clears it. Clicking the other one switches.
  - Answers stay changeable until midnight, as before.
- **Empty list:** "No friends yet — add names to your list", with an **Edit friend list…** button in this section.

### Log a contact

- A search field with the placeholder "Type a name…".
- **Matching:**
  - A name matches if it contains the query, ignoring case and accents.
  - Order: names that start with the query (any word in the name) come first, then the other matches. Each group is alphabetical.
  - Whitespace around the query is ignored.
- **Empty query:** the list shows friends logged today, so an undo is always reachable. If nobody has been logged today, no rows are shown.
- Each row is the friend's name, with a trailing "✓ today" if they were contacted today.
  - Clicking a row toggles their log for today, using the existing rule.
  - Logging today's pick is the same as pressing Contacted.
- **Return** toggles the top match, then clears the field.
- At most about 8 rows are visible; more rows scroll.

### Footer

- **Edit list…** opens `friends.txt`.
- **Open at login** is a checkbox. The existing failure note appears under the footer.
- **Quit.**

### Refresh

- Opening the panel refreshes the list and the day immediately.
- The one-minute timer, day-change, time-zone and wake events stay. The icon has to change color without the panel being opened.

## Calls (owner to confirm)

- An empty search shows today's logs rather than all friends.
- Return toggles the top match, so pressing it on someone already logged today undoes the log.
- Starts-with matches rank above contains matches.
- The search field gets keyboard focus when the panel opens, if the platform allows it reliably on macOS 13. If not, the field is one click away.

## Left to the builder

- Spacing, fonts and colors beyond what's stated above.
- How focus is implemented.
- Whether the search ranking lives in `FriendQueue`. Suggested: yes, as a pure function, so it can be tested on Linux.
