#!/usr/bin/env bash
# Builds PhoneAFriend.app from the Swift package (macOS only).
# Pass --install to copy it to ~/Applications and relaunch it.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"

swift build -c release --product PhoneAFriend
bin_dir="$(swift build -c release --show-bin-path)"

app="build/PhoneAFriend.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin_dir/PhoneAFriend" "$app/Contents/MacOS/PhoneAFriend"
cp App/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x PhoneAFriend || true
  # Launching while the old copy is still exiting fails with LaunchServices error -600.
  for _ in {1..50}; do
    pgrep -x PhoneAFriend >/dev/null || break
    sleep 0.1
  done
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/PhoneAFriend.app"
  cp -R "$app" "$HOME/Applications/"
  open "$HOME/Applications/PhoneAFriend.app"
  echo "Installed and launched ~/Applications/PhoneAFriend.app"
fi
