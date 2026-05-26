#!/usr/bin/env bash
# english-coach: analyze the user's prompt for English mistakes and surface
# feedback out-of-band (macOS notification + log file). Never blocks Claude,
# never adds anything to the conversation context.

set -euo pipefail

LOG="$HOME/.claude/english-coach.log"
MIN_WORDS=15

input=$(cat)
prompt=$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("prompt",""))' 2>/dev/null || echo "")

[ -z "$prompt" ] && exit 0

wc=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
[ "$wc" -lt "$MIN_WORDS" ] && exit 0

(
  feedback=$(claude -p "You are an English coach. The user is a Spanish native speaker. Analyze the following text for English mistakes or better phrasings. Respond in ONE short line (max 100 chars). If the English is fine, respond exactly with: OK

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

  esc=$(printf '%s' "$feedback" | sed 's/"/\\"/g')
  osascript -e "display notification \"$esc\" with title \"English Coach\"" 2>/dev/null || true
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
