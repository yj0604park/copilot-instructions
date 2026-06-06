#!/usr/bin/env bash
set -euo pipefail

memo_url="${MEMO_SERVICE_URL:-https://memo.paryoja.com}"
host="$(hostname -s 2>/dev/null || hostname)"
host="${host%%.*}"
host_lower="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"

case "$host_lower" in
  bookone) default_node_agent_name="dev-agent" ;;
  minitwo) default_node_agent_name="infra-agent" ;;
  minione) default_node_agent_name="app-agent" ;;
  raspberrypi) default_node_agent_name="rpi-agent" ;;
  yozit) default_node_agent_name="nas-agent" ;;
  *) default_node_agent_name="copilot-${host_lower}" ;;
esac

tty_name="$(tty 2>/dev/null || true)"
tty_name="${tty_name#/dev/}"
tty_name="$(printf '%s' "${tty_name:-notty}" | tr -c '[:alnum:]_.-' '-')"
instance_id="${COPILOT_AGENT_INSTANCE:-${host_lower}-${tty_name}-${PPID}}"
node_agent_name="${MEMO_NODE_AGENT_NAME:-$default_node_agent_name}"
agent_name="${MEMO_AGENT_NAME:-${node_agent_name}-${instance_id}}"

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/copilot"
mkdir -p "$state_dir"
cat > "$state_dir/memo-agent.env" <<EOF
MEMO_SERVICE_URL=${memo_url}
MEMO_AGENT_NAME=${agent_name}
MEMO_NODE_AGENT_NAME=${node_agent_name}
EOF
chmod 600 "$state_dir/memo-agent.env"

payload="$(printf '{"name":"%s","hostname":"%s","description":"GitHub Copilot CLI on %s (node inbox: %s)","capabilities":["coding","git","terminal","deploy","node:%s"]}' "$agent_name" "$host_lower" "$host_lower" "$node_agent_name" "$node_agent_name")"

curl -fsS -m 3 \
  -H "Content-Type: application/json" \
  -X POST \
  --data "$payload" \
  "${memo_url%/}/agents" >/dev/null

printf 'memo agent registered: %s (node inbox: %s)\n' "$agent_name" "$node_agent_name"
