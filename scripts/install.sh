#!/usr/bin/env bash
# Claude Notifier — Hook installer
# Configures Claude Code hooks to use notify.sh.
# Assumes the .app is already in /Applications (built by `make install`).
set -e

APP_NAME="ClaudeNotifier"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_PATH="/Applications/${APP_NAME}.app"
SETTINGS_DIR="$HOME/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

echo "╔════════════════════════════════════════╗"
echo "║   Claude Notifier — Hook Installer    ║"
echo "╚════════════════════════════════════════╝"
echo ""

# ---- check macOS -------------------------------------------------------------
if [ "$(uname)" != "Darwin" ]; then
    echo "❌ This installer only supports macOS."
    exit 1
fi

# ---- verify app exists -------------------------------------------------------
if [ ! -d "$INSTALL_PATH" ]; then
    echo "❌ $INSTALL_PATH not found. Run 'make install' first."
    exit 1
fi

# ---- configure Claude Code hooks ---------------------------------------------
echo "🔧 Configuring Claude Code hooks..."
mkdir -p "$SETTINGS_DIR"

NOTIFY_SH="$SCRIPT_DIR/notify.sh"
chmod +x "$NOTIFY_SH"

# Backup existing settings
if [ -f "$SETTINGS_FILE" ]; then
    BACKUP="$SETTINGS_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS_FILE" "$BACKUP"
    echo "📦 Backed up settings.json → $BACKUP"
else
    echo '{}' > "$SETTINGS_FILE"
fi

/usr/bin/python3 - "$SETTINGS_FILE" "$NOTIFY_SH" <<'PYEOF'
import json, sys
import re

settings_file, notify_sh = sys.argv[1], sys.argv[2]

with open(settings_file, 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        data = {}

if not isinstance(data, dict):
    data = {}

hooks = data.setdefault('hooks', {})

def is_claude_notifier_command(command):
    if not isinstance(command, str):
        return False
    if notify_sh in command:
        return True
    return bool(re.search(r'(^|[/"\s])notify\.sh(["\s]|$)', command))

def upsert(event, arg, matcher=None):
    cmd = f'"{notify_sh}" {arg}'
    matchers = hooks.setdefault(event, [])
    new_matchers = []
    for m in matchers:
        if not isinstance(m, dict):
            continue
        kept = []
        for h in m.get('hooks', []):
            if isinstance(h, dict) and is_claude_notifier_command(h.get('command')):
                continue
            kept.append(h)
        if kept:
            m['hooks'] = kept
            new_matchers.append(m)
    entry = {'hooks': [{'type': 'command', 'command': cmd}]}
    if matcher:
        entry['matcher'] = matcher
    new_matchers.append(entry)
    hooks[event] = new_matchers

upsert('Stop', 'stop')
upsert('Notification', 'notification', 'idle_prompt')
upsert('PermissionRequest', 'permission')

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"✅ Hooks written to {settings_file}")
PYEOF

# ---- launch the app ----------------------------------------------------------
echo "🚀 Launching ${APP_NAME}..."
open -a "$INSTALL_PATH" --args

# Verify it started
sleep 2
if pgrep -f "${APP_NAME}" >/dev/null 2>&1; then
    echo "✅ ${APP_NAME} is running"
else
    echo "⚠️  ${APP_NAME} may not have started. Check Activity Monitor."
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "  • ${APP_NAME} is running in your menu bar (look for 🔔)"
echo "  • Notifications will appear when Claude Code finishes or needs input"
echo "  • Click the menu bar icon for settings and recent history"
echo ""
echo "💡 Tip: In System Settings → Notifications, allow ClaudeNotifier to send alerts."
echo "   If notifications don't show, you may need to grant permission there."
echo ""
echo "🗑  To uninstall: cd $(dirname "$SCRIPT_DIR") && ./scripts/uninstall.sh"
