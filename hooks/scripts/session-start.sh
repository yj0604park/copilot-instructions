#!/usr/bin/env bash
# SessionStart hook: register this Copilot CLI session with memo-service.
# Runs register-memo-agent.sh, swallowing output. Never blocks session start.
set -u

repo_dir="$(dirname "$(readlink -f "$HOME/.copilot/copilot-instructions.md")")"
script="$repo_dir/scripts/register-memo-agent.sh"

log=/tmp/copilot-hook-session-start.log

if [[ -x "$script" ]]; then
  "$script" >>"$log" 2>&1 || echo "$(date): register failed exit=$?" >>"$log"
else
  echo "$(date): register script not found at $script" >>"$log"
fi

exit 0
