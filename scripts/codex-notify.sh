#!/usr/bin/env bash
# Code Notifier bridge for Codex `notify = [...]`.
# Sends a Codex completion event to CodeNotifier, then optionally forwards the
# same invocation to the previous Codex notify command.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTIFY_SH="$SCRIPT_DIR/notify.sh"

PAYLOAD=""
if [ ! -t 0 ]; then
    PAYLOAD=$(cat 2>/dev/null || true)
fi

if [ -x "$NOTIFY_SH" ]; then
    printf '%s' "$PAYLOAD" | "$NOTIFY_SH" codex_stop >/dev/null 2>&1 || true
fi

CODEX_NEXT_NOTIFY_FILE="$HOME/.codex/code-notifier-next-notify.json"
if [ -f "$CODEX_NEXT_NOTIFY_FILE" ]; then
    CODE_NOTIFIER_PAYLOAD="$PAYLOAD" /usr/bin/python3 - "$CODEX_NEXT_NOTIFY_FILE" "$@" <<'PYEOF' >/dev/null 2>&1 || true
import json, os, subprocess, sys

path = sys.argv[1]
extra_args = sys.argv[2:]
try:
    with open(path, "r", encoding="utf-8") as f:
        command = json.load(f)
except Exception:
    command = None

if isinstance(command, list) and command and all(isinstance(item, str) for item in command):
    payload = os.environ.get("CODE_NOTIFIER_PAYLOAD", "").encode("utf-8")
    if extra_args and command[-len(extra_args):] == extra_args:
        final_command = command
    else:
        final_command = command + extra_args
    subprocess.run(final_command, input=payload, timeout=3)
PYEOF
fi

exit 0
