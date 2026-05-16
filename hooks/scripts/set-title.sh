#!/bin/bash
# sessionStart hook: set iTerm2 tab title to "Copilot: {folder}"

INPUT=$(cat)
FOLDER=$(echo "$INPUT" | jq -r '.cwd // empty' | xargs basename 2>/dev/null)
FOLDER="${FOLDER:-unknown}"

if [ -n "$TMUX_PANE" ]; then
  tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
  if [ -n "$tty" ]; then
    printf '\ePtmux;\e\e]0;Copilot: %s\a\e\\' "$FOLDER" > "$tty" 2>/dev/null
  fi
fi
