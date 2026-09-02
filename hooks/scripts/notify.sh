#!/bin/bash
# agentStop hook: send iTerm2 notification with last assistant message summary

INPUT=$(cat)

FOLDER=$(echo "$INPUT" | jq -r '.cwd // empty' | xargs basename 2>/dev/null)
FOLDER="${FOLDER:-unknown}"
# The payload uses snake_case (session_id); camelCase is kept as a fallback in
# case the schema differs by version. Reading only .sessionId made SESSION_ID
# always empty, so the events file was never found and the summary never updated.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // .sessionId // empty')
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
EVENTS_FILE="$COPILOT_HOME/session-state/$SESSION_ID/events.jsonl"

SUMMARY="작업 완료"

if [ -n "$SESSION_ID" ] && [ -f "$EVENTS_FILE" ]; then
  sleep 1
  LAST_MSG=$(grep '"assistant.message"' "$EVENTS_FILE" \
    | tail -1 \
    | jq -r '.data.content // empty' 2>/dev/null \
    | tr '\n' ' ' \
    | cut -c1-80)
  if [ -n "$LAST_MSG" ]; then
    SUMMARY="$LAST_MSG"
  fi
fi

# Send notification to current tmux pane only
if [ -n "$TMUX_PANE" ]; then
  tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
  if [ -n "$tty" ]; then
    printf '\ePtmux;\e\e]9;Copilot [%s]: %s\a\e\\' "$FOLDER" "$SUMMARY" > "$tty" 2>/dev/null
  fi
fi
