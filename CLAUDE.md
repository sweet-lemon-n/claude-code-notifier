# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Install

```bash
# Build (SPM, zero external deps)
swift build -c release

# Package into .app bundle (binary + Info.plist + .icns)
bash scripts/package-app.sh

# Full install (kill old, copy to /Applications, re-register Launch Services)
pkill -f ClaudeNotifier; sleep 1
rm -rf /Applications/ClaudeNotifier.app
cp -R .build/ClaudeNotifier.app /Applications/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/ClaudeNotifier.app
open /Applications/ClaudeNotifier.app
```

## Test

```bash
# Send events to the running app (port file lives at ~/.claude/claude-notifier-port)
PORT=$(cat ~/.claude/claude-notifier-port)
curl -X POST "http://127.0.0.1:${PORT}/event" \
  -d '{"event":"stop","cwd":"/path/to/project"}'
curl -X POST "http://127.0.0.1:${PORT}/event" \
  -d '{"event":"notification","cwd":"/path/to/project","message":"confirm text"}'
```

## Architecture

**LSUIElement menu-bar app** — no Dock icon, no Cmd+Tab entry. Lives in the menu bar as a bell icon. Two channels for user input: (a) clicking the bell opens an NSPanel popup with recent notifications + settings; (b) UDP-style local HTTP server on `127.0.0.1:<random>` receives events from the bridge script.

### Data flow

```
Claude Code hooks (Stop / Notification)
  → ~/.claude/settings.json  →  calls scripts/notify.sh <event>
    → notify.sh reads stdin JSON (cwd, session_id, message), extracts cwd
      → curl POST http://127.0.0.1:<port>/event  {event, cwd, message}
        → IPCServer (Network.framework NWListener) parses HTTP, decodes HookPayload
          → DispatchQueue.main: AppDelegate.handleIncomingEvent(type, payload)
            → SoundManager.play(for:) — NSSound(contentsOfFile:)
            → NotificationManager.send(eventType, payload)
              → NotificationContentBuilder.build() — smart message from settings + payload
              → UNUserNotificationCenter.add() — native banner with icon, click→VSCode
                → History stored in @Published recentNotifications[]
```

### Key files

| File | Role |
|------|------|
| `main.swift` | `setActivationPolicy(.accessory)` before `NSApp.run()` |
| `AppDelegate.swift` | Central orchestrator: wires managers, owns statusItem, NSPanel popup, settings window |
| `IPCServer.swift` | Minimal HTTP server via Network.framework (no Swifter/vendored deps). Port written to `~/.claude/claude-notifier-port` |
| `NotificationManager.swift` | UNUserNotificationCenter with delegate for `willPresent` (always shows banner) and `didReceive` (click→VSCode). Also keeps `recentNotifications[]` history |
| `NotificationContentBuilder.swift` | Builds notification body from hook payload + user toggle settings (project name, timestamp, Claude's message) |
| `SoundManager.swift` | Plays system sounds from `/System/Library/Sounds/<name>.aiff` via `NSSound(contentsOfFile:)`, holds strong refs 10s to prevent ARC kill |
| `VSCodeManager.swift` | Activates VSCode via `NSRunningApplication.activate()` + `open -a "Visual Studio Code" <path>` |
| `SettingsStore.swift` | `@AppStorage`-backed singleton. Keys: sounds (stop/notification), toggles (projectName, timestamp, ClaudeMessage), behavior (launchAtLogin, muted) |
| `notify.sh` | Bash bridge called by Claude Code hooks. Extracts cwd/message from stdin JSON, forwards to app via curl. If app is down, launches it and retries 5×. Last-resort fallback: `afplay` sound only |

### Plist requirements

The app bundle's `Info.plist` must have concrete values (not Xcode variables):
- `CFBundleIdentifier`: `com.sweetlemon.ClaudeNotifier` (required for UNUserNotificationCenter)
- `CFBundleExecutable`: `ClaudeNotifier` (must match binary name)
- `CFBundleIconFile`: `AppIcon` (references AppIcon.icns in Resources/)
- `LSUIElement`: `true`

### Critical interactions

- **Notification permission**: `requestPermission()` must be called in `applicationDidFinishLaunching`. Without valid `CFBundleIdentifier` in Info.plist, the permission dialog never appears and UN delivers silently (no error, no banner).
- **Sound**: `NSSound(named:)` cached instances fail to replay (delegate issues). Always use `NSSound(contentsOfFile:byReference:false)` with explicit path. Keep strong reference until playback completes.
- **Popover positioning**: NSPopover and NSStatusBarButton have coordinate-space bugs on macOS 15+. The app uses a manually-positioned NSPanel with screen-coordinate conversion instead.
- **Bundle ID**: Changing `CFBundleIdentifier` requires `lsregister -f` to re-register with Launch Services; otherwise `open` says "executable is missing."
- **Hook config**: Located at `~/.claude/settings.json`. The `install.sh` script uses Python to UPSERT hooks (deduplicating by script path). Duplicate matchers cause double notifications.
- **swift-tools-version**: 5.9, macOS 14.0 deployment target. SPM `executableTarget` — produces a raw binary, NOT an .app. The packaging script assembles the .app structure manually.
