#!/usr/bin/env bash
# Register this Copilot CLI session with the memo-service agent mesh.
#
# Outputs (stdout): the path to the per-instance env file. Use as:
#   source "$(scripts/register-memo-agent.sh)"
# All progress/log lines are sent to stderr.
#
# Per-instance state: $XDG_STATE_HOME/copilot/memo-agent-{instance_id}.env
# Latest convenience symlink:   $XDG_STATE_HOME/copilot/memo-agent.env
set -euo pipefail

# Send all incidental output to stderr; reserve fd 3 for the state file path
exec 3>&1
exec 1>&2

memo_url="${MEMO_SERVICE_URL:-https://memo.paryoja.com}"
host="$(hostname -s 2>/dev/null || hostname)"
host="${host%%.*}"
host_lower="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"

# Per-instance id: explicit env wins, else tty+ppid, else random
if [[ -n "${COPILOT_AGENT_INSTANCE:-}" ]]; then
  instance_id="$COPILOT_AGENT_INSTANCE"
else
  tty_name="$(tty 2>/dev/null || true)"
  tty_name="${tty_name#/dev/}"
  tty_name="$(printf '%s' "${tty_name:-notty}" | tr -c '[:alnum:]_.-' '-')"
  instance_id="${tty_name}-${PPID:-0}"
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/copilot"
state_file="$state_dir/memo-agent-${instance_id}.env"
latest_link="$state_dir/memo-agent.env"
mkdir -p "$state_dir"

# Reuse uuid8 from this instance's existing env file if host matches
existing_name=""
if [[ -f "$state_file" ]]; then
  # shellcheck disable=SC1090
  source "$state_file" 2>/dev/null || true
  if [[ "${MEMO_NODE_HOSTNAME:-}" == "$host_lower" && "${MEMO_AGENT_NAME:-}" =~ ^${host_lower}-[0-9a-f]{8}$ ]]; then
    existing_name="$MEMO_AGENT_NAME"
  fi
fi

uuid8="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)"
agent_name="${MEMO_AGENT_NAME_OVERRIDE:-${existing_name:-${host_lower}-${uuid8}}}"

# Best-effort node registration (idempotent on backend)
curl -fsS -m 3 -H "Content-Type: application/json" -X POST \
  --data "$(printf '{"hostname":"%s","tailscale_name":"%s"}' "$host_lower" "$host_lower")" \
  "${memo_url%/}/nodes" >/dev/null || true

cat > "$state_file" <<EOF2
MEMO_SERVICE_URL=${memo_url}
MEMO_AGENT_NAME=${agent_name}
MEMO_NODE_HOSTNAME=${host_lower}
MEMO_AGENT_INSTANCE=${instance_id}
EOF2
chmod 600 "$state_file"

# Update "latest" symlink (best-effort; last-writer-wins)
ln -sfn "$state_file" "$latest_link" 2>/dev/null || true

# Resolve copilot-instructions repo HEAD for diagnostics
instructions_sha=""
if [[ -L "$HOME/.copilot/copilot-instructions.md" ]]; then
  inst_repo="$(dirname "$(readlink -f "$HOME/.copilot/copilot-instructions.md")")"
  if [[ -d "$inst_repo/.git" ]]; then
    instructions_sha="$(git -C "$inst_repo" rev-parse HEAD 2>/dev/null || true)"
  fi
fi

if [[ -n "$instructions_sha" ]]; then
  payload="$(printf '{"name":"%s","hostname":"%s","node_hostname":"%s","description":"GitHub Copilot CLI session on %s (instance %s)","capabilities":["coding","git","terminal"],"instructions_sha":"%s"}' \
    "$agent_name" "$host_lower" "$host_lower" "$host_lower" "$instance_id" "$instructions_sha")"
else
  payload="$(printf '{"name":"%s","hostname":"%s","node_hostname":"%s","description":"GitHub Copilot CLI session on %s (instance %s)","capabilities":["coding","git","terminal"]}' \
    "$agent_name" "$host_lower" "$host_lower" "$host_lower" "$instance_id")"
fi

curl -fsS -m 3 -H "Content-Type: application/json" -X POST \
  --data "$payload" "${memo_url%/}/agents" >/dev/null

printf 'memo agent registered: %s (node: %s, instance: %s, instr: %s)\n' \
  "$agent_name" "$host_lower" "$instance_id" "${instructions_sha:0:7}"

# Emit state file path on fd 3 for the caller to source
echo "$state_file" >&3
