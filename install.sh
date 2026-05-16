#!/usr/bin/env bash
# Dotfiles & Copilot CLI 셋업 — macOS / Debian-family (Raspberry Pi 포함)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

log()  { printf "\033[1;34m▶\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# ─────────────────────────────────────────────
# 1) OS / 패키지 매니저 감지
# ─────────────────────────────────────────────
case "$OS" in
  Darwin)
    PM="brew"
    ;;
  Linux)
    if have apt-get; then
      PM="apt"
    else
      err "지원되지 않는 Linux 배포판 (apt 필요). 수동 설치 필요."
      exit 1
    fi
    ;;
  *)
    err "지원되지 않는 OS: $OS"
    exit 1
    ;;
esac
ok "OS=$OS, package manager=$PM"

# ─────────────────────────────────────────────
# 2) 패키지 설치
# ─────────────────────────────────────────────
log "기본 패키지 설치 중..."

install_pkg() {
  case "$PM" in
    brew)
      have brew || { err "brew가 없습니다. https://brew.sh"; exit 1; }
      for p in "$@"; do
        brew list "$p" >/dev/null 2>&1 || brew install "$p"
      done
      ;;
    apt)
      have sudo || { err "sudo 필요"; exit 1; }
      sudo apt-get update -qq
      sudo apt-get install -y "$@"
      ;;
  esac
}

if [[ "$PM" == "brew" ]]; then
  install_pkg zsh tmux jq fzf zsh-autosuggestions zsh-completions starship zoxide
else
  # apt에 zsh-completions 없음 → git clone 으로 따로 처리
  # zoxide는 Debian 12+ / Ubuntu 22.04+ 에만 있어서 fallback 처리
  install_pkg zsh tmux jq fzf zsh-autosuggestions vim curl
  if ! have zoxide; then
    if apt-cache show zoxide >/dev/null 2>&1; then
      install_pkg zoxide
    fi
  fi
fi
ok "패키지 설치 완료"

# ─────────────────────────────────────────────
# 3) zsh-completions (apt에 없으면 git clone)
# ─────────────────────────────────────────────
if [[ "$PM" == "apt" ]] && [[ ! -d "$HOME/.zsh-completions" ]]; then
  log "zsh-completions clone 중..."
  git clone --depth 1 https://github.com/zsh-users/zsh-completions.git "$HOME/.zsh-completions"
  ok "$HOME/.zsh-completions 설치됨"
fi

# ─────────────────────────────────────────────
# 4) Starship (apt에 없으면 install.sh)
# ─────────────────────────────────────────────
if ! have starship; then
  log "starship 설치 중..."
  mkdir -p "$HOME/.local/bin"
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
  ok "starship 설치 (~/.local/bin)"
else
  ok "starship 이미 설치됨"
fi

# ─────────────────────────────────────────────
# 4-1) zoxide (apt에 없으면 install.sh)
# ─────────────────────────────────────────────
if ! have zoxide; then
  log "zoxide 설치 중..."
  mkdir -p "$HOME/.local/bin"
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- --bin-dir "$HOME/.local/bin"
  ok "zoxide 설치 (~/.local/bin)"
else
  ok "zoxide 이미 설치됨"
fi

# ─────────────────────────────────────────────
# 5) Symlink 셋업
# ─────────────────────────────────────────────
log "symlink 생성 중..."

mkdir -p "$HOME/.copilot/hooks/scripts"
mkdir -p "$HOME/.config"

link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" ]]; then
    ln -sf "$src" "$dst"
  elif [[ -e "$dst" ]]; then
    warn "$dst 이미 존재 (일반 파일). $dst.bak 으로 백업"
    mv "$dst" "$dst.bak"
    ln -sf "$src" "$dst"
  else
    ln -sf "$src" "$dst"
  fi
  ok "$dst → $src"
}

link "$REPO_DIR/tmux.conf"                       "$HOME/.tmux.conf"
link "$REPO_DIR/vimrc"                           "$HOME/.vimrc"
link "$REPO_DIR/zshrc"                           "$HOME/.zshrc"
link "$REPO_DIR/starship.toml"                   "$HOME/.config/starship.toml"
link "$REPO_DIR/instructions.md"                 "$HOME/.copilot/copilot-instructions.md"
link "$REPO_DIR/hooks/notification.json"         "$HOME/.copilot/hooks/notification.json"
link "$REPO_DIR/hooks/scripts/notify.sh"         "$HOME/.copilot/hooks/scripts/notify.sh"
[[ -f "$REPO_DIR/hooks/scripts/notify-event.sh" ]] && \
  link "$REPO_DIR/hooks/scripts/notify-event.sh" "$HOME/.copilot/hooks/scripts/notify-event.sh"

# ─────────────────────────────────────────────
# 6) 기본 셸을 zsh로 (선택)
# ─────────────────────────────────────────────
ZSH_PATH="$(command -v zsh || true)"
if [[ -n "$ZSH_PATH" ]] && [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
  warn "기본 셸이 zsh가 아닙니다 (현재: ${SHELL:-unknown})"
  echo "    변경하려면: chsh -s $ZSH_PATH"
fi

# ─────────────────────────────────────────────
# 7) 검증
# ─────────────────────────────────────────────
echo
log "검증:"
bash "$REPO_DIR/check-symlinks.sh"

echo
ok "셋업 완료!"
echo
echo "다음 단계:"
echo "  1. 새 zsh 세션 시작:  exec zsh   (또는 재로그인)"
echo "  2. Copilot CLI 재시작 (hooks 적용)"
echo "  3. 터미널 폰트를 Nerd Font 로 변경 (선택, starship 아이콘 표시용)"
echo "     - 추천: MesloLGS NF / JetBrainsMono Nerd Font / FiraCode Nerd Font"
echo "     - https://www.nerdfonts.com/"
