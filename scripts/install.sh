#!/bin/bash
# Build UsageBar, install it into /Applications, and enable Open at Login.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Applications/UsageBar.app"

"$ROOT/scripts/build-app.sh"

# Quit a running copy so the bundle can be replaced cleanly.
if pgrep -f "$DEST/Contents/MacOS/UsageBar" >/dev/null 2>&1; then
    osascript -e 'tell application "UsageBar" to quit' >/dev/null 2>&1 || \
        pkill -f "$DEST/Contents/MacOS/UsageBar" || true
    sleep 1
fi

rm -rf "$DEST"
ditto "$ROOT/build/UsageBar.app" "$DEST"
codesign --verify --deep --strict "$DEST"

# Launch through LaunchServices so SMAppService can register this bundle as a login item.
open -a "$DEST" --args --login-item enable
STATUS="$("$DEST/Contents/MacOS/UsageBar" --login-item status || true)"
printf 'Installed %s\n%s\n' "$DEST" "$STATUS"

open -a "$DEST"
