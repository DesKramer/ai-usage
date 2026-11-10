#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release

APP="$ROOT/build/UsageBar.app"
CONTENTS="$APP/Contents"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/.build/release/UsageBar" "$CONTENTS/MacOS/UsageBar"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT"/Resources/*.svg "$CONTENTS/Resources/"

SIGNING_IDENTITY="${USAGEBAR_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/Apple Development:/{print $2; exit}')"
fi
if [[ -z "$SIGNING_IDENTITY" ]]; then
    # Fall back to any valid code signing identity (e.g. a local development cert) so the
    # app keeps a stable identity across rebuilds instead of being ad-hoc signed.
    SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -F'"' '/^ *[0-9]+\)/{print $2; exit}')"
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP"
    printf 'Built %s (signed as %s)\n' "$APP" "$SIGNING_IDENTITY"
else
    codesign --force --deep --sign - "$APP"
    printf 'Built %s (ad-hoc signed; Keychain may ask again after rebuilding)\n' "$APP"
fi
