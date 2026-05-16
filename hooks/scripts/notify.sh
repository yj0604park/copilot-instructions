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

# Send notification to current tmux pane only
if [ -n "$TMUX_PANE" ]; then
  tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
  if [ -n "$tty" ]; then
    printf '\ePtmux;\e\e]9;Copilot: %s\a\e\\' "$SUMMARY" > "$tty" 2>/dev/null
  fi
fi
