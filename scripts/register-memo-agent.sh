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
# Track whether the caller explicitly pinned a URL (then we never override it).
memo_url_explicit="${MEMO_SERVICE_URL:+yes}"

# Reachability probe + fallback to a direct backend address.
# The default URL (memo.paryoja.com) enters via MiniTwo Traefik and proxies to
# the minione backend. If that public path is down, try reaching the backend
# directly. Fallback order:
#   1. $MEMO_SERVICE_URL_FALLBACK (node-specific override)
#   2. minione over the tailnet (subnet-independent; works for any node whose
#      Tailscale does real TCP)
#   3. minione over LAN (for nodes like Synology on userspace Tailscale, which
#      can't do host-originated tailnet TCP but share the 10.0.0.0/24 subnet)
# Nodes that match none just fall through (each miss costs ~3s). The caller
# pinning MEMO_SERVICE_URL disables all of this.
_probe_memo() { curl -fsS -m 3 -o /dev/null "${1%/}/openapi.json" 2>/dev/null; }
if [[ -z "$memo_url_explicit" ]] && ! _probe_memo "$memo_url"; then
  for cand in "${MEMO_SERVICE_URL_FALLBACK:-}" \
              "http://minione.tail591527.ts.net:8100" \
              "http://10.0.0.144:8100"; do
    [[ -n "$cand" ]] || continue
    if _probe_memo "$cand"; then
      echo "primary memo-service $memo_url unreachable; falling back to $cand" >&2
      memo_url="$cand"
      break
    fi
  done
fi

host="$(hostname -s 2>/dev/null || hostname)"
host="${host%%.*}"
host_lower="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"

# Per-instance id: explicit env wins, else the Copilot session id (stable across
# every tool call within one session), else tty+ppid, else random. Using the
# session id keeps the identity stable even though each bash tool call may run
# under a different ppid/tty.
if [[ -n "${COPILOT_AGENT_INSTANCE:-}" ]]; then
  instance_id="$COPILOT_AGENT_INSTANCE"
elif [[ -n "${COPILOT_AGENT_SESSION_ID:-}" ]]; then
  instance_id="$COPILOT_AGENT_SESSION_ID"
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

# Derive the per-session suffix from the Copilot session id when available so
# the MCP server (which sees the same COPILOT_AGENT_SESSION_ID) can compute an
# identical name and share one identity per session. Falls back to random for
# older clients that don't export a session id.
if [[ -n "${COPILOT_AGENT_SESSION_ID:-}" ]]; then
  uuid8="$(printf '%s' "$COPILOT_AGENT_SESSION_ID" | tr -d '-' | tr '[:upper:]' '[:lower:]' | head -c 8)"
else
  uuid8="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)"
fi
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

# --- Background heartbeat daemon (no LLM tokens) ---
# Keep this agent "online" while the Copilot session lives, without waking the
# model. A fully detached daemon pings /heartbeat every 5 min and self-terminates
# when the owning Copilot process exits, so the agent goes offline naturally on
# the server's idle timeout. Detaching (setsid / nohup+disown) is what keeps the
# CLI's TUI from showing a perpetual "working" spinner. Skips if one is already
# running for this instance.
_start_heartbeat_daemon() {
  local pidfile="$state_dir/hb-${instance_id}.pid"
  if [[ -f "$pidfile" ]]; then
    local old; old="$(cat "$pidfile" 2>/dev/null || true)"
    if [[ -n "$old" ]] && kill -0 "$old" 2>/dev/null; then
      return 0  # already running for this instance
    fi
  fi
  # Find the Copilot process to watch by walking up the parent chain; fall back
  # to the immediate parent if none matches.
  local watch_pid="$PPID" p="$PPID" comm
  while [[ "${p:-0}" -gt 1 ]]; do
    comm="$(ps -o comm= -p "$p" 2>/dev/null || true)"
    if [[ "$comm" == *copilot* ]]; then watch_pid="$p"; break; fi
    p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ' || true)"
  done
  local runner=""
  command -v setsid >/dev/null 2>&1 && runner="setsid"
  $runner nohup bash -c '
    hb_url="$1"; watch="$2"; pf="$3"
    echo $$ > "$pf"
    trap "rm -f \"$pf\"; exit 0" TERM INT
    while kill -0 "$watch" 2>/dev/null; do
      curl -fsS -m 5 -o /dev/null -X POST -H "Content-Type: application/json" \
        -d "{}" "$hb_url" 2>/dev/null || true
      sleep 300
    done
    rm -f "$pf"
  ' _ "${memo_url%/}/agents/${agent_name}/heartbeat" "$watch_pid" "$pidfile" \
    </dev/null >/dev/null 2>&1 3>&- &
  disown 2>/dev/null || true
}
_start_heartbeat_daemon || true

# Emit state file path on fd 3 for the caller to source
echo "$state_file" >&3
