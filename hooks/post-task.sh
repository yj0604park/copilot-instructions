#!/bin/bash
# Copilot CLI post-task hook
# 작업 완료 시 iTerm2 알림을 SSH + tmux 환경에서 로컬로 전송

MESSAGE="${1:-작업 완료}"

# tmux passthrough로 iTerm2 알림 전송
for tty in $(tmux list-panes -a -F '#{pane_tty}' 2>/dev/null); do
  printf '\ePtmux;\e\e]9;Copilot: %s\a\e\\' "$MESSAGE" > "$tty" 2>/dev/null
done
