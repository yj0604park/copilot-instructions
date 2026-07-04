#!/usr/bin/env bash
# sync-secondary-dns.sh
#
# Pull local DNS records from the PRIMARY pihole (yozit) to this SECONDARY
# resolver (raspberrypi) so that LAN name resolution keeps working when the
# primary is down. Only reloads dnsmasq when something actually changed.
#
# STATUS: requires SSH access to the primary to be configured first.
#   - Set YOZIT_SSH to a reachable ssh target with key auth, e.g.
#       export YOZIT_SSH="diehard@100.101.180.8"   # yozit tailscale IP
#   - The account must be able to read the pihole custom.list + local dnsmasq
#     record files (pihole runs in docker with host network on yozit).
#
# What it syncs:
#   * pihole custom.list (hosts-format local A records) -> pihole-custom.hosts
#   * pihole custom *.conf local records (host-record/cname/address) if present
#
# Blocklist/gravity sync is intentionally NOT done here (see reply to yozit):
#   the secondary is a name-resolution failover, not a full adblock replica.
set -euo pipefail

YOZIT_SSH="${YOZIT_SSH:-}"
DEST_DIR="/etc/dnsmasq.d"
HOSTS_DEST="${DEST_DIR}/pihole-custom.hosts"
# Common pihole locations (adjust once yozit layout is confirmed).
REMOTE_CUSTOM_LIST="${REMOTE_CUSTOM_LIST:-/etc/pihole/custom.list}"

if [[ -z "$YOZIT_SSH" ]]; then
  echo "ERROR: set YOZIT_SSH (e.g. diehard@100.101.180.8) — SSH access to primary not configured yet." >&2
  exit 2
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Pull custom.list (hosts format: "10.0.0.5  host.lan")
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$YOZIT_SSH" "sudo cat '$REMOTE_CUSTOM_LIST' 2>/dev/null || cat '$REMOTE_CUSTOM_LIST'" > "$tmp"; then
  echo "ERROR: failed to fetch $REMOTE_CUSTOM_LIST from $YOZIT_SSH" >&2
  exit 1
fi

changed=0
if ! diff -q "$tmp" "$HOSTS_DEST" >/dev/null 2>&1; then
  sudo cp "$tmp" "$HOSTS_DEST"
  changed=1
fi

if [[ "$changed" == "1" ]]; then
  sudo systemctl reload dnsmasq 2>/dev/null || sudo systemctl restart dnsmasq
  echo "$(date -Is) secondary DNS records updated from primary" 
else
  echo "$(date -Is) no change"
fi
