#!/bin/bash
# agentStop hook: send iTerm2 notification with last assistant message summary

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // empty')
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
EVENTS_FILE="$COPILOT_HOME/session-state/$SESSION_ID/events.jsonl"

SUMMARY="작업 완료"

if [ -n "$SESSION_ID" ] && [ -f "$EVENTS_FILE" ]; then
  LAST_MSG=$(grep '"assistant.message"' "$EVENTS_FILE" \
    | tail -1 \
    | jq -r '.data.content // empty' 2>/dev/null \
    | head -c 80)
  if [ -n "$LAST_MSG" ]; then
    SUMMARY="$LAST_MSG"
  fi
fi

# Send notification to all tmux panes (SSH + tmux -> iTerm2)
for tty in $(tmux list-panes -a -F '#{pane_tty}' 2>/dev/null); do
  printf '\ePtmux;\e\e]9;Copilot: %s\a\e\\' "$SUMMARY" > "$tty" 2>/dev/null
done
