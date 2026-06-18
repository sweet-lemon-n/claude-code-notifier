#!/usr/bin/env bash
# Claude Notifier bridge script
# Called by Claude Code hooks (Stop / Notification).
# Forwards event data to the running ClaudeNotifier.app via local HTTP.
# Falls back to osascript if the app is not running.
set -u

EVENT="${1:-stop}"
PORT_FILE="$HOME/.claude/claude-notifier-port"

# ---- read hook JSON from stdin ------------------------------------------------
PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD=$(cat 2>/dev/null || true)
fi

# ---- extract cwd -------------------------------------------------------------
CWD=""
if [ -n "$PAYLOAD" ]; then
    CWD=$(/usr/bin/python3 -c "
import sys,json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('cwd',''))
except Exception:
    pass
" <<< "$PAYLOAD" 2>/dev/null || true)
fi
[ -z "$CWD" ] && CWD="${PWD:-}"

# ---- extract message for Notification events ---------------------------------
MSG=""
if [ -n "$PAYLOAD" ] && [ "$EVENT" = "notification" ]; then
    MSG=$(/usr/bin/python3 -c "
import sys,json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('message',''))
except Exception:
    pass
" <<< "$PAYLOAD" 2>/dev/null || true)
fi

# ---- try to reach the running app --------------------------------------------
if [ -f "$PORT_FILE" ]; then
    PORT=$(cat "$PORT_FILE" 2>/dev/null || true)
    if [ -n "$PORT" ]; then
        SEND_JSON=$(/usr/bin/python3 -c "
import json
out = {'event':'$EVENT','cwd':'$CWD'}
if '$MSG': out['message'] = '$MSG'
print(json.dumps(out))
" 2>/dev/null || true)

        if [ -n "$SEND_JSON" ]; then
            curl -s -X POST "http://127.0.0.1:${PORT}/event" \
                -H "Content-Type: application/json" \
                -d "$SEND_JSON" \
                --max-time 2 >/dev/null 2>&1 && exit 0
        fi
    fi
fi

# ---- fallback: direct osascript notification (app not running) ----------------
TITLE="Claude Code"
SUBTITLE=""
MESSAGE=""
SOUND="Glass"

case "$EVENT" in
    stop)
        SUBTITLE="Task Complete"
        MESSAGE="Claude is ready — awaiting your next instruction"
        SOUND="Glass"
        ;;
    notification)
        SUBTITLE="Needs Your Confirmation"
        if [ -n "$MSG" ]; then
            MESSAGE="$MSG"
        else
            MESSAGE="Claude is waiting for your input"
        fi
        SOUND="Ping"
        ;;
esac

escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

SOUND_FILE="/System/Library/Sounds/${SOUND}.aiff"
if [ -f "$SOUND_FILE" ]; then
    /usr/bin/afplay "$SOUND_FILE" >/dev/null 2>&1 &
fi

TITLE_E=$(escape "$TITLE")
SUBTITLE_E=$(escape "$SUBTITLE")
MESSAGE_E=$(escape "$MESSAGE")
/usr/bin/osascript -e "display notification \"${MESSAGE_E}\" with title \"${TITLE_E}\" subtitle \"${SUBTITLE_E}\" sound name \"${SOUND}\"" >/dev/null 2>&1 || true

exit 0
