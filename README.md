# Phone a Friend

A macOS menu bar app that suggests one friend to text or call each day. Friends you've never contacted come first, in random order; after that, whoever you've gone longest without contacting. The phone icon stays orange until you answer the day's suggestion. Clicking it opens a panel with today's friend and a search box for logging contacts with anyone else.

## Build and install (macOS 13+)

```bash
scripts/build-app.sh --install
```

This builds `build/PhoneAFriend.app`, signs it ad hoc, copies it to `~/Applications`, and launches it.

## Your data

Both files live in `~/Library/Application Support/PhoneAFriend/`:

- `friends.txt` — your list, one name per line. Blank lines and lines starting with `#` are ignored. Open it from the menu with **Edit friend list…**.
- `state.json` — contact history, written by the app.

## Tests

The rotation rules live in the `FriendQueue` library and run on Linux in Docker:

```bash
scripts/test-linux.sh
```

On a Mac, `swift test` works too.
