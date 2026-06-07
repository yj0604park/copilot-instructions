#!/usr/bin/env bash
# Register this Copilot CLI session with the memo-service agent mesh.
# - Picks a unique agent name {hostname}-{uuid8} per session
# - Ensures the node is registered (idempotent)
# - Persists MEMO_* env vars to $XDG_STATE_HOME/copilot/memo-agent.env
set -euo pipefail

memo_url="${MEMO_SERVICE_URL:-https://memo.paryoja.com}"
host="$(hostname -s 2>/dev/null || hostname)"
host="${host%%.*}"
host_lower="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"

# Stable per-session uuid8: reuse from existing env file if present and matches host
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/copilot"
state_file="$state_dir/memo-agent.env"
mkdir -p "$state_dir"

existing_name=""
if [[ -f "$state_file" ]]; then
  # shellcheck disable=SC1090
  source "$state_file" 2>/dev/null || true
  if [[ "${MEMO_NODE_HOSTNAME:-}" == "$host_lower" && "${MEMO_AGENT_NAME:-}" =~ ^${host_lower}-[0-9a-f]{8}$ ]]; then
    existing_name="$MEMO_AGENT_NAME"
  fi
fi

uuid8="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)"
agent_name="${MEMO_AGENT_NAME:-${existing_name:-${host_lower}-${uuid8}}}"

# Best-effort node registration (idempotent on backend)
curl -fsS -m 3 -H "Content-Type: application/json" -X POST \
  --data "$(printf '{"hostname":"%s","tailscale_name":"%s"}' "$host_lower" "$host_lower")" \
  "${memo_url%/}/nodes" >/dev/null || true

cat > "$state_file" <<EOF2
MEMO_SERVICE_URL=${memo_url}
MEMO_AGENT_NAME=${agent_name}
MEMO_NODE_HOSTNAME=${host_lower}
EOF2
chmod 600 "$state_file"

payload="$(printf '{"name":"%s","hostname":"%s","node_hostname":"%s","description":"GitHub Copilot CLI session on %s","capabilities":["coding","git","terminal"]}' \
  "$agent_name" "$host_lower" "$host_lower" "$host_lower")"

curl -fsS -m 3 -H "Content-Type: application/json" -X POST \
  --data "$payload" "${memo_url%/}/agents" >/dev/null

printf 'memo agent registered: %s (node: %s)\n' "$agent_name" "$host_lower"
