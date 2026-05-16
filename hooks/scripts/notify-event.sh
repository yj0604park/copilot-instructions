#!/bin/bash
# notification hook: shell 완료 등 비동기 이벤트 알림

INPUT=$(cat)

TYPE=$(echo "$INPUT" | jq -r '.notificationType // empty')
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' | tr '\n' ' ' | head -c 80)

if [ -z "$MESSAGE" ]; then
  MESSAGE="$TYPE"
fi

if [ -n "$TMUX_PANE" ]; then
  tty=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
  if [ -n "$tty" ]; then
    printf '\ePtmux;\e\e]9;Copilot [%s]: %s\a\e\\' "$TYPE" "$MESSAGE" > "$tty" 2>/dev/null
  fi
fi
