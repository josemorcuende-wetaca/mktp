#!/usr/bin/env bash
# english-coach: analyze the user's prompt for English mistakes and surface
# feedback out-of-band (macOS notification + log file). Never blocks Claude,
# never adds anything to the conversation context.

set -euo pipefail

# === Defaults (override in ~/.claude/english-coach.conf) ===
NOTIFY_TITLE="English Coach"
NOTIFY_ICON=""           # path to a PNG/JPG to use as the notification icon
NOTIFY_SENDER_ID=""      # bundle id of an app to impersonate (e.g. "com.apple.Terminal")
LOG="$HOME/.claude/english-coach.log"
LOCK="$HOME/.claude/.english-coach.lock"
MIN_WORDS=15
COOLDOWN_SEC=60          # at most one analyzer call per N seconds
ANALYZER_MARKER="ENGCOACH-ANALYZER-9bj3"

# Per-user overrides. The conf file is plain bash assignments and is NOT
# shipped with the plugin — each user creates their own.
USER_CONFIG="$HOME/.claude/english-coach.conf"
[ -f "$USER_CONFIG" ] && . "$USER_CONFIG"

# === Recursion guards (after one runaway burned a full session quota) ===
#
# The background `claude -p` below spawns a child Claude session that also
# has this plugin installed, so its UserPromptSubmit hook fires too. Two
# independent guards stop the recursion:
#
#   1. ENGLISH_COACH_RUNNING env var set on the child invocation.
#   2. Sentinel marker embedded in the analyzer's prompt; if we see it in
#      stdin we know this hook fired on our own meta-prompt — exit.
#
# Plus a cooldown lockfile so even an unexpected burst can't fan out faster
# than COOLDOWN_SEC. Designed for Max-subscription users whose limit is
# session quota, not dollars.

# Guard 1: env var
if [ "${ENGLISH_COACH_RUNNING:-0}" = "1" ]; then
  exit 0
fi

input=$(cat)
prompt=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null || echo "")

[ -z "$prompt" ] && exit 0

# Guard 2: sentinel marker
case "$prompt" in
  *"$ANALYZER_MARKER"*) exit 0 ;;
esac

wc=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
[ "$wc" -lt "$MIN_WORDS" ] && exit 0

# Guard 3: cooldown — at most one analyzer per COOLDOWN_SEC
if [ -f "$LOCK" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  [ "$age" -lt "$COOLDOWN_SEC" ] && exit 0
fi
mkdir -p "$(dirname "$LOCK")"
touch "$LOCK"

(
  # Cost/scope limits on the analyzer:
  #   --model haiku   ~10x cheaper, plenty for grammar checks
  #   --tools ""      analyzer doesn't need tools — purely text-out
  feedback=$(ENGLISH_COACH_RUNNING=1 claude -p \
    --model haiku \
    --tools "" \
    "[$ANALYZER_MARKER] You are an English coach. The user is a Spanish native speaker. Analyze the following text for English mistakes or better phrasings. Respond in ONE short line (max 100 chars). If the English is fine, respond exactly with: OK

Text: $prompt" 2>/dev/null || echo "")

  feedback=$(printf '%s' "$feedback" | head -c 200 | tr -d '\n')

  if [ -z "$feedback" ] || [ "$feedback" = "OK" ]; then
    exit 0
  fi

  ts=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "$(dirname "$LOG")"
  {
    echo "[$ts]"
    echo "  Original: $(printf '%s' "$prompt" | head -c 200)"
    echo "  Feedback: $feedback"
    echo
  } >> "$LOG"

  # Prefer terminal-notifier (custom icon + clickable to open the log).
  # Fall back to osascript if it's not installed.
  if command -v terminal-notifier >/dev/null 2>&1; then
    tn_args=(
      -title "$NOTIFY_TITLE"
      -message "$feedback"
      -group "english-coach"
      -execute "open '$LOG'"
    )
    [ -n "$NOTIFY_ICON" ] && [ -f "$NOTIFY_ICON" ] && tn_args+=(-appIcon "$NOTIFY_ICON")
    [ -n "$NOTIFY_SENDER_ID" ] && tn_args+=(-sender "$NOTIFY_SENDER_ID")
    terminal-notifier "${tn_args[@]}" >/dev/null 2>&1 || true
  else
    esc=$(printf '%s' "$feedback" | sed 's/"/\\"/g')
    title_esc=$(printf '%s' "$NOTIFY_TITLE" | sed 's/"/\\"/g')
    osascript -e "display notification \"$esc\" with title \"$title_esc\"" 2>/dev/null || true
  fi
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
