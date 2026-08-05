#!/usr/bin/env bash
# Delete stale agent records from memo-service.
#
# Agents are meant to expire on their own: the server marks one offline once it
# stops sending heartbeats, and a session's heartbeat daemon exits when the
# session goes quiet. That leaves the record behind though, so /agents slowly
# fills with dead sessions -- the desktop app opens a fresh session (and thus a
# fresh agent) whenever an old one ages out, so the list only grows.
#
# This prunes records that have not been seen for a while. It is a cleanup tool,
# not a fix: if agents pile up *while still reporting online*, something is
# heartbeating on behalf of dead sessions and that root cause needs fixing
# instead (see the daemon notes in register-memo-agent.sh).
#
# Usage:
#   prune-memo-agents.sh                  # dry run, 60 min threshold
#   prune-memo-agents.sh --apply          # actually delete
#   prune-memo-agents.sh --older-than 30 --apply
#   prune-memo-agents.sh --node bookone --apply
#   prune-memo-agents.sh --keep bookone-93c48888 --apply
set -euo pipefail

memo_url="${MEMO_SERVICE_URL:-https://memo.paryoja.com}"
threshold_min=60
apply=0
node_filter=""
keep=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)       apply=1; shift ;;
    --older-than)  threshold_min="$2"; shift 2 ;;
    --node)        node_filter="$2"; shift 2 ;;
    --keep)        keep+=("$2"); shift 2 ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

# Never prune the agent belonging to the current session.
if [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/copilot/memo-agent.env" ]]; then
  # shellcheck disable=SC1091
  source "${XDG_STATE_HOME:-$HOME/.local/state}/copilot/memo-agent.env" 2>/dev/null || true
  [[ -n "${MEMO_AGENT_NAME:-}" ]] && keep+=("$MEMO_AGENT_NAME")
fi

agents_json="$(curl -fsS -m 10 "${memo_url%/}/agents")" || {
  echo "failed to fetch ${memo_url%/}/agents" >&2; exit 1; }

keep_json="$(printf '%s\n' "${keep[@]+"${keep[@]}"}" | jq -R . | jq -s .)"

# bash 3.2 (macOS default) has no mapfile, and this also runs on Synology's
# older shell, so collect with a plain read loop.
stale=()
while IFS= read -r line; do
  [[ -n "$line" ]] && stale+=("$line")
done < <(
  printf '%s' "$agents_json" | jq -r \
    --argjson keep "$keep_json" \
    --argjson max "$threshold_min" \
    --arg node "$node_filter" '
    (now) as $now
    | .[]
    | select($node == "" or .node_hostname == $node)
    | select(.name as $n | ($keep | index($n)) | not)
    | . as $a
    | ((.last_seen // "1970-01-01T00:00:00Z")
       | sub("\\.[0-9]+";"") | sub("Z$";"Z")
       | fromdateiso8601) as $seen
    | select((($now - $seen) / 60) >= $max)
    | "\($a.name)\t\((($now - $seen)/60) | floor)\t\($a.status)"
  '
)

if [[ ${#stale[@]} -eq 0 ]]; then
  echo "nothing to prune (threshold ${threshold_min}m)"
  exit 0
fi

echo "stale agents (idle >= ${threshold_min}m): ${#stale[@]}"
printf '  %s\n' "${stale[@]}" | head -20
[[ ${#stale[@]} -gt 20 ]] && echo "  ... and $(( ${#stale[@]} - 20 )) more"

if [[ $apply -eq 0 ]]; then
  echo
  echo "dry run -- re-run with --apply to delete"
  exit 0
fi

deleted=0 failed=0
for line in "${stale[@]}"; do
  name="${line%%$'\t'*}"
  if curl -fsS -m 10 -o /dev/null -X DELETE "${memo_url%/}/agents/${name}" 2>/dev/null; then
    deleted=$((deleted + 1))
  else
    failed=$((failed + 1))
    echo "  failed: $name" >&2
  fi
done
echo "deleted=$deleted failed=$failed"
