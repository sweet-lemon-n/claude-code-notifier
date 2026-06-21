#!/usr/bin/env bash
# Code Notifier — hook installer
# Configures Claude Code hooks and Codex notify integration.
# Assumes the .app is already in /Applications (built by `make install`).
set -e

APP_NAME="CodeNotifier"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_PATH="/Applications/${APP_NAME}.app"
SETTINGS_DIR="$HOME/.claude"
SETTINGS_FILE="$SETTINGS_DIR/settings.json"

echo "╔════════════════════════════════════════╗"
echo "║   Code Notifier — Hook Installer      ║"
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

NOTIFY_SH="$INSTALL_PATH/Contents/Resources/notify.sh"
if [ ! -f "$NOTIFY_SH" ]; then
    NOTIFY_SH="$SCRIPT_DIR/notify.sh"
fi
chmod +x "$NOTIFY_SH"
CODEX_NOTIFY_SH="$INSTALL_PATH/Contents/Resources/codex-notify.sh"
if [ ! -f "$CODEX_NOTIFY_SH" ]; then
    CODEX_NOTIFY_SH="$SCRIPT_DIR/codex-notify.sh"
fi
chmod +x "$CODEX_NOTIFY_SH"

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
upsert('PreToolUse', 'question', 'AskUserQuestion')

with open(settings_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"✅ Hooks written to {settings_file}")
PYEOF

# ---- configure Codex notify --------------------------------------------------
CODEX_CONFIG="$HOME/.codex/config.toml"
CODEX_NEXT_NOTIFY="$HOME/.codex/code-notifier-next-notify.json"
if [ -f "$CODEX_CONFIG" ]; then
    echo "🔧 Configuring Codex completion notify..."
    CODEX_BACKUP="$CODEX_CONFIG.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CODEX_CONFIG" "$CODEX_BACKUP"
    /usr/bin/python3 - "$CODEX_CONFIG" "$CODEX_NOTIFY_SH" "$CODEX_NEXT_NOTIFY" <<'PYEOF'
import ast
import json
import re
import sys

config_file, codex_notify_sh, next_notify_file = sys.argv[1], sys.argv[2], sys.argv[3]

with open(config_file, "r", encoding="utf-8") as f:
    lines = f.readlines()

notify_line_re = re.compile(r"^notify\s*=\s*(\[.*\])\s*$")
new_notify = f'notify = [{json.dumps(codex_notify_sh)}, "turn-ended"]\n'
found = False
previous = None
out = []

for line in lines:
    match = notify_line_re.match(line.strip())
    if match and not found:
        found = True
        try:
            parsed = ast.literal_eval(match.group(1))
            if isinstance(parsed, list) and parsed and parsed[0] != codex_notify_sh:
                previous = [str(item) for item in parsed]
        except Exception:
            previous = None
        out.append(new_notify)
    else:
        out.append(line)

if not found:
    insert_at = 0
    while insert_at < len(out) and out[insert_at].strip() and not out[insert_at].lstrip().startswith("["):
        insert_at += 1
    out.insert(insert_at, new_notify)

if previous:
    with open(next_notify_file, "w", encoding="utf-8") as f:
        json.dump(previous, f, ensure_ascii=False, indent=2)

with open(config_file, "w", encoding="utf-8") as f:
    f.writelines(out)

print(f"✅ Codex notify written to {config_file}")
PYEOF
else
    echo "ℹ️  Codex config not found; skipping Codex notify integration."
fi

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
echo "  • Notifications will appear when Claude Code or Codex finishes"
echo "  • Claude Code confirmation prompts can still alert immediately"
echo "  • Click the menu bar icon for settings and recent history"
echo ""
echo "💡 Tip: In System Settings → Notifications, allow CodeNotifier to send alerts."
echo "   If notifications don't show, you may need to grant permission there."
echo ""
echo "🗑  To uninstall: cd $(dirname "$SCRIPT_DIR") && ./scripts/uninstall.sh"
