#!/usr/bin/env bash
# Keep copilot-instructions on latest origin/main before launching Copilot CLI.
# Best-effort only: never blocks a session from starting.
#
# NOT dead code: invoked by the `copilot()` wrapper in this repo's `zshrc`
# (symlinked to ~/.zshrc on every machine). The call site greps as
# "scripts/sync-instructions.sh" and contains no "copilot" substring, so
# searching for the latter alone will wrongly suggest nothing references this.
set -u

log="/tmp/copilot-instructions-sync.log"
export GIT_TERMINAL_PROMPT=0

log_msg() {
  printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$*" >>"$log"
}

# yozit (Synology) keeps git off the default PATH.
GIT="$(command -v git 2>/dev/null || true)"
[[ -z "$GIT" && -x /usr/local/bin/git ]] && GIT=/usr/local/bin/git
if [[ -z "$GIT" ]]; then
  log_msg "skip: git not found (PATH=$PATH)"
  exit 0
fi

instructions_link="$HOME/.copilot/copilot-instructions.md"
resolved_instructions="$(readlink -f "$instructions_link" 2>/dev/null || true)"

if [[ -z "$resolved_instructions" ]]; then
  log_msg "skip: cannot resolve $instructions_link"
  exit 0
fi

repo_dir="$(dirname "$resolved_instructions")"

if [[ -z "$repo_dir" || ! -d "$repo_dir/.git" ]]; then
  log_msg "skip: repo not found from $instructions_link"
  exit 0
fi

cd "$repo_dir" || {
  log_msg "skip: cannot cd $repo_dir"
  exit 0
}

branch="$("$GIT" branch --show-current 2>/dev/null || true)"
if [[ "$branch" != "main" ]]; then
  log_msg "skip: branch=$branch"
  exit 0
fi

if [[ -n "$("$GIT" status --porcelain 2>/dev/null)" ]]; then
  log_msg "skip: dirty worktree"
  exit 0
fi

if ! "$GIT" fetch --prune origin main >>"$log" 2>&1; then
  log_msg "fetch failed"
  exit 0
fi

if [[ "$("$GIT" rev-parse HEAD 2>/dev/null)" == "$("$GIT" rev-parse origin/main 2>/dev/null)" ]]; then
  log_msg "already up-to-date"
  exit 0
fi

if "$GIT" merge-base --is-ancestor HEAD origin/main 2>/dev/null; then
  "$GIT" merge --ff-only origin/main >>"$log" 2>&1 || log_msg "merge failed"
else
  log_msg "skip: local main diverged from origin/main"
fi

exit 0
