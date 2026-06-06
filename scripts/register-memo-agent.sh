#!/usr/bin/env bash
set -euo pipefail

memo_url="${MEMO_SERVICE_URL:-https://memo.paryoja.com}"
host="$(hostname -s 2>/dev/null || hostname)"
host="${host%%.*}"
host_lower="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
agent_name="${MEMO_AGENT_NAME:-copilot-cli-${host_lower}}"

payload="$(printf '{"name":"%s","hostname":"%s","description":"GitHub Copilot CLI on %s","capabilities":["coding","git","terminal","deploy"]}' "$agent_name" "$host_lower" "$host_lower")"

curl -fsS -m 3 \
  -H "Content-Type: application/json" \
  -X POST \
  --data "$payload" \
  "${memo_url%/}/agents" >/dev/null

printf 'memo agent registered: %s\n' "$agent_name"
