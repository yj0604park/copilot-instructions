#!/usr/bin/env bash
# Periodic *safe* fast-forward pull of tracked repos.
#
# Repo set mirrors what the homelab-node-agent reports: explicit `git_repos`
# plus the immediate git children of each `git_repos_scan` dir (read from
# node-agent.json). Falls back to scanning ~/Workspace if no config.
#
# Safety: only ever fast-forwards. A repo is pulled *only* when its working
# tree is clean, it has an upstream, and it is strictly behind (never ahead /
# diverged). Never merges, rebases, stashes, or discards local work. Any repo
# that doesn't meet the bar is silently skipped. The node-agent already runs an
# authenticated `git fetch` (incl. cross-account gh fallback) every interval, so
# the local ff-merge here needs no network; a best-effort fetch is still tried.
set -uo pipefail

# node-agent config path differs per machine; auto-discover across known
# locations unless NODE_AGENT_CONFIG is set explicitly.
CONFIG="${NODE_AGENT_CONFIG:-}"
if [[ -z "$CONFIG" ]]; then
  for c in "$HOME/projects/apps/homelab-node-agent/node-agent.json" \
           "$HOME/homelab-node-agent/node-agent.json" \
           "$HOME/.config/homelab-node-agent/config.json"; do
    [[ -f "$c" ]] && { CONFIG="$c"; break; }
  done
fi
LOG="${AUTO_PULL_LOG:-$HOME/.local/state/copilot/auto-pull.log}"
mkdir -p "$(dirname "$LOG")"

# yozit (Synology) keeps git off the default PATH.
GIT="$(command -v git 2>/dev/null || true)"
[[ -z "$GIT" && -x /usr/local/bin/git ]] && GIT=/usr/local/bin/git
[[ -z "$GIT" ]] && { echo "git not found" >&2; exit 1; }

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "$LOG"; }

expand() { case "$1" in "~"*) printf '%s\n' "${1/#\~/$HOME}" ;; *) printf '%s\n' "$1" ;; esac; }

repos=()
if [[ -f "$CONFIG" ]] && command -v python3 >/dev/null 2>&1; then
  while IFS= read -r r; do [[ -n "$r" ]] && repos+=("$(expand "$r")"); done < <(
    python3 - "$CONFIG" <<'PY'
import json, sys, os, glob
try:
    c = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
out = list(c.get("git_repos") or [])
for d in c.get("git_repos_scan") or []:
    dd = os.path.expanduser(d)
    for child in sorted(glob.glob(os.path.join(dd, "*"))):
        if os.path.isdir(os.path.join(child, ".git")):
            out.append(child)
for p in out:
    print(p)
PY
  )
fi
if [[ ${#repos[@]} -eq 0 ]]; then
  for base in "$HOME/projects" "$HOME/projects/apps" "$HOME/Workspace"; do
    [[ -d "$base" ]] || continue
    for child in "$base"/*; do [[ -d "$child/.git" ]] && repos+=("$child"); done
  done
  [[ -d "$HOME/homelab-node-agent/.git" ]] && repos+=("$HOME/homelab-node-agent")
fi

# bash 3.2 treats "${empty[@]}" under `set -u` as unbound and aborts; bail early.
if [[ ${#repos[@]} -eq 0 ]]; then
  log "no repos to track (config=${CONFIG:-none})"
  exit 0
fi

updated=0; skipped=0
for repo in "${repos[@]}"; do
  [[ -d "$repo/.git" ]] || continue
  cd "$repo" 2>/dev/null || continue
  # dirty working tree -> never touch
  if [[ -n "$("$GIT" status --porcelain 2>/dev/null)" ]]; then skipped=$((skipped+1)); continue; fi
  # must track an upstream
  "$GIT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || { skipped=$((skipped+1)); continue; }
  "$GIT" fetch --quiet 2>/dev/null || true
  behind="$("$GIT" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)"
  ahead="$("$GIT" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  if [[ "$behind" -gt 0 && "$ahead" -eq 0 ]]; then
    if "$GIT" merge --ff-only '@{u}' >/dev/null 2>&1; then
      log "pulled $(basename "$repo") +$behind -> $("$GIT" rev-parse --short HEAD)"
      updated=$((updated+1))
    else
      log "FAILED ff-merge $(basename "$repo")"
    fi
  fi
done
log "done: $updated updated, $skipped skipped, ${#repos[@]} tracked"
