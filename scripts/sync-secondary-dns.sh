#!/usr/bin/env bash
# sync-secondary-dns.sh
#
# Mirror the PRIMARY pihole's local DNS records (yozit) onto this SECONDARY
# pihole (raspberrypi) so LAN name resolution keeps working when the primary
# is DOWN. Both run Pi-hole v6 in docker.
#
# What it syncs (overwrites, since the secondary is a pure replica):
#   * dns.hosts        (local A/AAAA records, "IP domain" lines)
#   * dns.cnameRecords ("domain,target[,ttl]" entries)
#
# Blocklist/gravity is NOT synced here: each pihole maintains its own
# gravity from its own blocklists (StevenBlack etc.), so adblock already
# survives a primary outage without syncing.
#
# Requirements:
#   - key-based SSH to the primary (default paryoja@100.101.180.8, yozit tailnet)
#   - docker access on both ends
#
# Env overrides:
#   YOZIT_SSH       ssh target of primary          (default paryoja@100.101.180.8)
#   YOZIT_SSH_PORT  ssh port of primary            (default 10022)
#   YOZIT_DOCKER  docker binary path on primary  (default /usr/local/bin/docker)
#   PIHOLE_NAME   container name on both ends     (default pihole)
set -euo pipefail

YOZIT_SSH="${YOZIT_SSH:-paryoja@100.101.180.8}"
YOZIT_SSH_PORT="${YOZIT_SSH_PORT:-10022}"
YOZIT_DOCKER="${YOZIT_DOCKER:-/usr/local/bin/docker}"
PIHOLE_NAME="${PIHOLE_NAME:-pihole}"

log() { echo "$(date -Is) $*"; }

# Pick a working local docker command (group member -> plain; else sudo -n).
if docker info >/dev/null 2>&1; then
  LDOCKER=(docker)
elif sudo -n docker info >/dev/null 2>&1; then
  LDOCKER=(sudo -n docker)
else
  echo "ERROR: no usable local docker (add user to docker group or configure sudo)" >&2
  exit 1
fi

# Extract the quoted items of a pihole.toml array key from stdin.
# Usage: extract_array KEY < pihole.toml   -> one raw item per line (no quotes)
extract_array() {
  awk -v key="$1" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=[[:space:]]*\\[" { infield=1 }
    infield {
      while (match($0, /"[^"]*"/)) {
        s = substr($0, RSTART+1, RLENGTH-2)
        print s
        $0 = substr($0, RSTART+RLENGTH)
      }
      if ($0 ~ /\]/) exit
    }
  '
}

# Turn newline-separated raw items into a pihole-FTL config array literal.
to_array_literal() {
  local first=1 out="[ "
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ $first -eq 1 ]]; then first=0; else out+=", "; fi
    out+="\"$line\""
  done
  out+=" ]"
  # Empty array stays "[  ]" -> normalise to "[]"
  [[ "$out" == "[  ]" ]] && out="[]"
  echo "$out"
}

# --- Pull primary's pihole.toml once ---
if ! remote_toml="$(ssh -p "$YOZIT_SSH_PORT" -o ConnectTimeout=8 -o BatchMode=yes "$YOZIT_SSH" \
      "$YOZIT_DOCKER exec $PIHOLE_NAME cat /etc/pihole/pihole.toml" 2>/dev/null)"; then
  echo "ERROR: failed to read primary pihole.toml via $YOZIT_SSH" >&2
  exit 1
fi

changed=0
for pair in "dns.hosts:hosts" "dns.cnameRecords:cnameRecords"; do
  key="${pair%%:*}"; leaf="${pair##*:}"
  desired="$(printf '%s\n' "$remote_toml" | extract_array "$leaf" | to_array_literal)"
  current="$("${LDOCKER[@]}" exec "$PIHOLE_NAME" pihole-FTL --config "$key" 2>/dev/null || echo '?')"
  # Normalise both to a comparable form (strip spaces/quotes/brackets).
  norm() { tr -d ' "[]' | tr ',' '\n' | sort; }
  if [[ "$(printf '%s' "$desired" | norm)" != "$(printf '%s' "$current" | norm)" ]]; then
    "${LDOCKER[@]}" exec "$PIHOLE_NAME" pihole-FTL --config "$key" "$desired" >/dev/null
    log "updated $key -> $desired"
    changed=1
  fi
done

if [[ "$changed" -eq 0 ]]; then
  log "no change"
fi
