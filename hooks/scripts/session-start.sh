#!/usr/bin/env bash
# SessionStart hook: register this Copilot CLI session with memo-service.
# Runs register-memo-agent.sh, swallowing output. Never blocks session start.
#
# The session id must be passed explicitly: hooks do not inherit
# COPILOT_AGENT_SESSION_ID from the session's tool environment, so without this
# the script fell through to its tty+ppid fallback and minted a brand new
# "not-a-tty-<ppid>" agent on every invocation (85 ghost agents accumulated
# that way). The hook payload carries the id on stdin, so forward it.
set -u

INPUT=$(cat 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.sessionId // empty' 2>/dev/null || true)
[[ -n "${SID:-}" ]] && export COPILOT_AGENT_INSTANCE="$SID"

repo_dir="$(dirname "$(readlink -f "$HOME/.copilot/copilot-instructions.md")")"
script="$repo_dir/scripts/register-memo-agent.sh"

log=/tmp/copilot-hook-session-start.log

if [[ -x "$script" ]]; then
  "$script" >>"$log" 2>&1 || echo "$(date): register failed exit=$?" >>"$log"
else
  echo "$(date): register script not found at $script" >>"$log"
fi

exit 0
