#!/usr/bin/env bash
set -euo pipefail

memo_url="${MEMO_SERVICE_URL:-https://memo.paryoja.com}"
host="$(hostname -s 2>/dev/null || hostname)"
host="${host%%.*}"
host_lower="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"

case "$host_lower" in
  bookone) default_agent_name="dev-agent" ;;
  minitwo) default_agent_name="infra-agent" ;;
  minione) default_agent_name="app-agent" ;;
  raspberrypi) default_agent_name="rpi-agent" ;;
  yozit) default_agent_name="nas-agent" ;;
  *) default_agent_name="copilot-cli-${host_lower}" ;;
esac

agent_name="${MEMO_AGENT_NAME:-$default_agent_name}"

payload="$(printf '{"name":"%s","hostname":"%s","description":"GitHub Copilot CLI on %s","capabilities":["coding","git","terminal","deploy"]}' "$agent_name" "$host_lower" "$host_lower")"

curl -fsS -m 3 \
  -H "Content-Type: application/json" \
  -X POST \
  --data "$payload" \
  "${memo_url%/}/agents" >/dev/null

printf 'memo agent registered: %s\n' "$agent_name"
