#!/usr/bin/env bash
# Claude Notifier — uninstaller
# Removes the app, cleans up hooks, and deletes the port file.
set -e

APP_NAME="ClaudeNotifier"
INSTALL_PATH="/Applications/${APP_NAME}.app"
SETTINGS_FILE="$HOME/.claude/settings.json"
PORT_FILE="$HOME/.claude/claude-notifier-port"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════╗"
echo "║   Claude Notifier — Uninstaller       ║"
echo "╚════════════════════════════════════════╝"
echo ""

# ---- stop the app ------------------------------------------------------------
echo "🛑 Stopping ${APP_NAME}..."
pkill -f "${APP_NAME}" 2>/dev/null || true
sleep 1

# ---- remove from /Applications -----------------------------------------------
if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
    echo "✅ Removed ${INSTALL_PATH}"
else
    echo "⚠️  ${INSTALL_PATH} not found"
fi

# ---- remove port file --------------------------------------------------------
if [ -f "$PORT_FILE" ]; then
    rm -f "$PORT_FILE"
    echo "✅ Removed port file"
fi

# ---- remove hooks from settings.json -----------------------------------------
if [ -f "$SETTINGS_FILE" ]; then
    BACKUP="$SETTINGS_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS_FILE" "$BACKUP"
    echo "📦 Backed up settings.json → $BACKUP"

    NOTIFY_SH="$SCRIPT_DIR/notify.sh"
    /usr/bin/python3 - "$SETTINGS_FILE" "$NOTIFY_SH" <<'PYEOF'
import json, sys
import re

settings_file, notify_sh = sys.argv[1], sys.argv[2]

with open(settings_file, 'r', encoding='utf-8') as f:
    try:
        data = json.load(f)
    except json.JSONDecodeError:
        print("⚠️  settings.json is not valid JSON")
        sys.exit(0)

if not isinstance(data, dict):
    print("⚠️  settings.json has unexpected structure")
    sys.exit(0)

hooks = data.get('hooks', {})
removed = False

def is_claude_notifier_command(command):
    if not isinstance(command, str):
        return False
    if notify_sh in command:
        return True
    return bool(re.search(r'(^|[/"\s])notify\.sh(["\s]|$)', command))

for event in ['Stop', 'Notification', 'PermissionRequest', 'PreToolUse']:
    if event not in hooks:
        continue
    matchers = hooks[event]
    new_matchers = []
    for m in matchers:
        if not isinstance(m, dict):
            continue
        kept = []
        for h in m.get('hooks', []):
            if isinstance(h, dict) and is_claude_notifier_command(h.get('command')):
                removed = True
                continue
            kept.append(h)
        if kept:
            m['hooks'] = kept
            new_matchers.append(m)
    if new_matchers:
        hooks[event] = new_matchers
    else:
        del hooks[event]

if hooks:
    data['hooks'] = hooks
elif 'hooks' in data:
    del data['hooks']

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

if removed:
    print("✅ Hooks removed from settings.json")
else:
    print("⚠️  No matching hooks found in settings.json")
PYEOF

fi

echo ""
echo "✅ Uninstall complete. Claude Notifier has been removed."
