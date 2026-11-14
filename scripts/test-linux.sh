#!/usr/bin/env bash
# Runs the FriendQueue tests on Linux inside the official Swift image.
# A separate scratch path keeps Linux build products away from the Mac's .build/.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$repo:/src" -w /src swift:6.1 \
  swift test --scratch-path .build-linux "$@"
