# UsageBar

A small native macOS menu bar app for Claude Code and Codex subscription limits.

The menu bar shows the lowest remaining allowance for each provider. Open it to see the 5-hour and weekly windows, reset times, a locally recorded 12-hour drawdown chart, and the last successful update.

## Requirements

- macOS 13 or newer
- Claude Code signed in with `claude`
- Codex signed in with `codex login`

## Build and run

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open build/UsageBar.app
```

Move `build/UsageBar.app` to `/Applications` before enabling **Open at Login** so macOS can keep a stable path to the app.

## How credentials are used

UsageBar reads Codex credentials from `~/.codex/auth.json` and Claude credentials from the `Claude Code-credentials` item in Keychain. It reads that item through `/usr/bin/security`, the same tool Claude Code uses to create and read it, so macOS does not ask for your password. The token is kept in memory and the Keychain item is read again only when the token is about to expire, the API rejects it, or you click Refresh.

The build script uses the first available Apple Development signing identity, or the identity set in `USAGEBAR_SIGNING_IDENTITY`. This gives UsageBar a stable identity so Keychain can remember that approval across rebuilds. It falls back to ad-hoc signing when no development identity is available; ad-hoc builds may need approval again after rebuilding.

Credentials stay in memory only. UsageBar sends them directly to the provider usage endpoints and stores only the last usage percentages and reset times in `~/Library/Application Support/UsageBar/usage.json`.

The app refreshes every five minutes while it is running. Manual refreshes update immediately. The 12-hour chart records the 5-hour allowance after each successful refresh, so it fills in over time rather than backfilling provider history. If a provider throttles a request, UsageBar keeps showing the last successful result and marks it as stale.
# ai-usage
