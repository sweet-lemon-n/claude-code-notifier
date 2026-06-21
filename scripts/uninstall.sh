#!/usr/bin/env bash
# Code Notifier — uninstaller
# Removes the app, cleans up hooks, and deletes the port file.
set -e

APP_NAME="CodeNotifier"
INSTALL_PATH="/Applications/${APP_NAME}.app"
OLD_INSTALL_PATH="/Applications/ClaudeNotifier.app"
SETTINGS_FILE="$HOME/.claude/settings.json"
PORT_FILE="$HOME/.claude/claude-notifier-port"
CODEX_CONFIG="$HOME/.codex/config.toml"
CODEX_NEXT_NOTIFY="$HOME/.codex/code-notifier-next-notify.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════╗"
echo "║   Code Notifier — Uninstaller         ║"
echo "╚════════════════════════════════════════╝"
echo ""

# ---- stop the app ------------------------------------------------------------
echo "🛑 Stopping ${APP_NAME}..."
pkill -f "${APP_NAME}" 2>/dev/null || true
pkill -f "ClaudeNotifier" 2>/dev/null || true
sleep 1

# ---- remove from /Applications -----------------------------------------------
if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
    echo "✅ Removed ${INSTALL_PATH}"
else
    echo "⚠️  ${INSTALL_PATH} not found"
fi
if [ -d "$OLD_INSTALL_PATH" ]; then
    rm -rf "$OLD_INSTALL_PATH"
    echo "✅ Removed ${OLD_INSTALL_PATH}"
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

# ---- restore Codex notify ----------------------------------------------------
if [ -f "$CODEX_CONFIG" ]; then
    BACKUP="$CODEX_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CODEX_CONFIG" "$BACKUP"
    /usr/bin/python3 - "$CODEX_CONFIG" "$CODEX_NEXT_NOTIFY" <<'PYEOF'
import json
import re
import sys

config_file, next_notify_file = sys.argv[1], sys.argv[2]
try:
    with open(next_notify_file, "r", encoding="utf-8") as f:
        previous = json.load(f)
except Exception:
    previous = None

with open(config_file, "r", encoding="utf-8") as f:
    lines = f.readlines()

notify_line_re = re.compile(r"^notify\s*=\s*\[.*codex-notify\.sh.*\]\s*$")
out = []
removed = False
for line in lines:
    if notify_line_re.match(line.strip()):
        removed = True
        if isinstance(previous, list) and all(isinstance(item, str) for item in previous):
            out.append("notify = " + json.dumps(previous, ensure_ascii=False) + "\n")
        continue
    out.append(line)

with open(config_file, "w", encoding="utf-8") as f:
    f.writelines(out)

if removed:
    print("✅ Codex notify restored")
else:
    print("⚠️  No Code Notifier Codex notify entry found")
PYEOF
    rm -f "$CODEX_NEXT_NOTIFY"
fi

echo ""
echo "✅ Uninstall complete. Code Notifier has been removed."
