#!/usr/bin/env bash
# agentStop hook: keep this Copilot session's memo-service agent marked online.
#
# Runs after every assistant turn, so an active session is refreshed to "online"
# on each response — no LLM tokens, no long-running daemon required. This is the
# primary liveness signal; the register-memo-agent.sh heartbeat daemon only
# covers long idle gaps *between* turns. Because agentStop fires on resumed and
# restarted sessions too (unlike SessionStart), this closes the gap where a
# resumed session had no daemon and got falsely swept offline after the idle
# timeout.
set -u

INPUT=$(cat 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.sessionId // empty' 2>/dev/null)

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/copilot"
envf=""
if [[ -n "$SID" && -f "$state_dir/memo-agent-$SID.env" ]]; then
  envf="$state_dir/memo-agent-$SID.env"
elif [[ -L "$state_dir/memo-agent.env" || -f "$state_dir/memo-agent.env" ]]; then
  envf="$state_dir/memo-agent.env"
fi

register() {
  local repo
  repo="$(dirname "$(readlink -f "$HOME/.copilot/copilot-instructions.md" 2>/dev/null)" 2>/dev/null)"
  # Forward the session id: hooks don't inherit COPILOT_AGENT_SESSION_ID, and
  # without it the script falls back to a tty+ppid instance id that differs on
  # every call, registering a new agent each time instead of refreshing this one.
  [[ -n "${SID:-}" ]] && export COPILOT_AGENT_INSTANCE="$SID"
  [[ -x "$repo/scripts/register-memo-agent.sh" ]] && \
    "$repo/scripts/register-memo-agent.sh" >/dev/null 2>&1 || true
}

if [[ -z "$envf" ]]; then
  # No env yet (e.g. resumed session that never ran SessionStart) -> full register.
  register
  exit 0
fi

# shellcheck disable=SC1090
source "$envf" 2>/dev/null || true
url="${MEMO_SERVICE_URL:-https://memo.paryoja.com}"
name="${MEMO_AGENT_NAME:-}"
[[ -z "$name" ]] && { register; exit 0; }

# Mark the session as active. The heartbeat daemon polls this file's mtime and
# exits once it goes stale, which is how it learns the session ended -- it has no
# session-scoped process to watch (all sessions share one `copilot --server`).
act="${MEMO_AGENT_ACTIVITY_FILE:-}"
if [[ -n "$act" ]]; then
  touch "$act" 2>/dev/null || true
else
  # Older env file predating the activity mechanism; re-register to add it.
  register
fi

code=$(curl -fsS -m 5 -o /dev/null -w '%{http_code}' \
  -X POST -H 'Content-Type: application/json' -d '{}' \
  "$url/agents/$name/heartbeat" 2>/dev/null || echo 000)

# 404 = agent record gone (GC'd / never registered) -> re-register (also restarts daemon).
[[ "$code" == "404" ]] && register

exit 0
