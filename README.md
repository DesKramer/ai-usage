# UsageBar

<img width="422" height="479" alt="Screenshot 2026-11-03 at 09 48 34" src="https://github.com/user-attachments/assets/3bf33e01-6deb-49f8-8328-f536fc96b0ad" />




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

To build and install with Open at Login enabled in one step:

```bash
./scripts/install.sh
```

That copies the app to `/Applications/UsageBar.app`, registers it as a login item, and launches it. macOS records login items against the app bundle path, so install to `/Applications` before enabling **Open at Login**; otherwise macOS loses track of the app after you move it. The login item can also be managed from the menu bar: `--login-item enable`, `disable`, or `status` are accepted as launch arguments when you need to do it without the UI.

## How credentials are used

UsageBar reads Codex credentials from `~/.codex/auth.json` and Claude credentials from the `Claude Code-credentials` item in Keychain. It reads that item through `/usr/bin/security`, the same tool Claude Code uses to create and read it, so macOS does not ask for your password. The token is kept in memory and the Keychain item is read again only when the token is about to expire, the API rejects it, or you click Refresh.

The build script uses the first Apple Development signing identity, then any other valid code signing identity, or the identity set in `USAGEBAR_SIGNING_IDENTITY`. This gives UsageBar a stable identity so Keychain can remember that approval across rebuilds. It falls back to ad-hoc signing when no development identity is available; ad-hoc builds may need approval again after rebuilding.

Credentials stay in memory only. UsageBar sends them directly to the provider usage endpoints and stores only the last usage percentages and reset times in `~/Library/Application Support/UsageBar/usage.json`.

The app refreshes every five minutes while it is running. Manual refreshes update immediately. The 12-hour chart records the 5-hour allowance after each successful refresh, so it fills in over time rather than backfilling provider history. If a provider throttles a request, UsageBar keeps showing the last successful result and marks it as stale.
# ai-usage
