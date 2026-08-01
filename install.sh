#!/usr/bin/env bash
# Dotfiles & Copilot CLI 셋업 — macOS / Debian-family (Raspberry Pi 포함)
#
#   install.sh            데스크톱 셋업 (GUI 앱/폰트 포함)
#   install.sh --server   서버 셋업 (cask/GUI/폰트 제외, CLI + dotfile만)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
SERVER_MODE="${SERVER_MODE:-0}"

for arg in "$@"; do
  case "$arg" in
    --server) SERVER_MODE=1 ;;
    -h|--help)
      sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "알 수 없는 인자: $arg (사용법: $0 [--server])" >&2
      exit 1
      ;;
  esac
done

log()  { printf "\033[1;34m▶\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

if [[ "$SERVER_MODE" == "1" ]]; then
  log "server 모드: GUI 앱(cask)/폰트 설치 skip"
fi

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
      # apt 없는 Linux(예: Synology NAS) → core-only 모드.
      # 패키지/툴 설치는 건너뛰고 symlink + install stamp 만 수행.
      PM="none"
      warn "apt 없음 → core-only 모드 (symlink + stamp 만, 패키지 설치 skip)"
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

if [[ "$PM" == "none" ]]; then
  warn "core-only 모드: 패키지/툴 설치 단계 전부 skip"
fi

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
  if [[ -f "$REPO_DIR/Brewfile" ]]; then
    if [[ "$SERVER_MODE" == "1" ]]; then
      # cask(GUI 앱/폰트)와 그 전용 tap 을 뺀 임시 Brewfile 로 설치.
      # 별도 Brewfile.server 를 두면 두 파일이 갈라지므로 필터링 방식을 쓴다.
      SERVER_BREWFILE="$(mktemp -t Brewfile.server)"
      grep -Ev '^[[:space:]]*(cask|tap)[[:space:]]' "$REPO_DIR/Brewfile" > "$SERVER_BREWFILE"
      log "Brewfile(cask 제외)로 패키지 설치 중..."
      brew bundle --file="$SERVER_BREWFILE" || warn "brew bundle 일부 실패 (계속 진행)"
      rm -f "$SERVER_BREWFILE"
    else
      log "Brewfile로 패키지 설치 중..."
      brew bundle --file="$REPO_DIR/Brewfile" || warn "brew bundle 일부 실패 (계속 진행)"
    fi
  else
    install_pkg zsh tmux jq fzf zsh-autosuggestions zsh-completions starship zoxide atuin gh node
  fi
elif [[ "$PM" == "apt" ]]; then
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
# 4~4-3) 툴 설치 (core-only 모드에서는 전부 skip)
# ─────────────────────────────────────────────
if [[ "$PM" == "none" ]]; then
  warn "core-only: starship/zoxide/atuin/oh-my-zsh/plugins 설치 skip"
else

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
# 4-1b) atuin (apt에 없으면 공식 installer)
# ─────────────────────────────────────────────
if ! have atuin; then
  log "atuin 설치 중..."
  mkdir -p "$HOME/.local/bin"
  curl -sSfL https://setup.atuin.sh | \
    env ATUIN_NO_MODIFY_PATH=1 ATUIN_INSTALL_DIR="$HOME/.local/bin" \
    sh -s -- --non-interactive
  ok "atuin 설치 (~/.local/bin/)"
else
  ok "atuin 이미 설치됨"
fi

# ─────────────────────────────────────────────
# 4-2) oh-my-zsh (공식 installer, unattended, zshrc 보존)
# ─────────────────────────────────────────────
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  log "oh-my-zsh 설치 중..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" \
    --unattended --keep-zshrc
  ok "oh-my-zsh 설치"
else
  ok "oh-my-zsh 이미 설치됨"
fi

# ─────────────────────────────────────────────
# 4-3) oh-my-zsh 외부 plugins
# ─────────────────────────────────────────────
OMZ_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$OMZ_CUSTOM/plugins"

clone_omz_plugin() {
  local name="$1" url="$2"
  local dst="$OMZ_CUSTOM/plugins/$name"
  if [[ -d "$dst/.git" ]]; then
    ok "oh-my-zsh plugin: $name 이미 설치됨"
  else
    git clone --depth 1 "$url" "$dst"
    ok "oh-my-zsh plugin: $name 설치"
  fi
}

clone_omz_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions.git
clone_omz_plugin zsh-syntax-highlighting  https://github.com/zsh-users/zsh-syntax-highlighting.git

fi  # end core-only tool-install guard

# ─────────────────────────────────────────────
# 5) Symlink 셋업
# ─────────────────────────────────────────────
log "symlink 생성 중..."

mkdir -p "$HOME/.copilot/hooks/scripts"
mkdir -p "$HOME/.config/atuin"

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

link "$REPO_DIR/atuin.toml"                       "$HOME/.config/atuin/config.toml"
link "$REPO_DIR/tmux.conf"                       "$HOME/.tmux.conf"
link "$REPO_DIR/vimrc"                           "$HOME/.vimrc"
link "$REPO_DIR/zshrc"                           "$HOME/.zshrc"
link "$REPO_DIR/starship.toml"                   "$HOME/.config/starship.toml"
link "$REPO_DIR/instructions.md"                 "$HOME/.copilot/copilot-instructions.md"
link "$REPO_DIR/hooks/notification.json"         "$HOME/.copilot/hooks/notification.json"
link "$REPO_DIR/hooks/scripts/notify.sh"         "$HOME/.copilot/hooks/scripts/notify.sh"
[[ -f "$REPO_DIR/hooks/scripts/notify-event.sh" ]] && \
  link "$REPO_DIR/hooks/scripts/notify-event.sh" "$HOME/.copilot/hooks/scripts/notify-event.sh"
[[ -f "$REPO_DIR/hooks/scripts/session-start.sh" ]] && \
  link "$REPO_DIR/hooks/scripts/session-start.sh" "$HOME/.copilot/hooks/scripts/session-start.sh"
[[ -f "$REPO_DIR/hooks/scripts/heartbeat.sh" ]] && \
  link "$REPO_DIR/hooks/scripts/heartbeat.sh" "$HOME/.copilot/hooks/scripts/heartbeat.sh"

# ─────────────────────────────────────────────
# 5b) SSH config (Include 방식)
# ─────────────────────────────────────────────
# repo의 ssh/config 를 ~/.ssh/config 상단에서 Include 한다.
# symlink 대신 Include 라 머신별/일회성 호스트는 로컬 ~/.ssh/config 에 유지 가능.
log "SSH config Include 배선 중..."
SSH_DIR="$HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
INC_LINE="Include $REPO_DIR/ssh/config"
# 아래 ok/warn 메시지의 "~/.ssh/..." 는 표시용 문자열이지 경로 확장 대상이 아니다.
# shellcheck disable=SC2088
if [[ ! -f "$SSH_DIR/config" ]]; then
  printf '%s\n' "$INC_LINE" > "$SSH_DIR/config"
  ok "~/.ssh/config 생성 + Include 추가"
elif ! grep -qxF "$INC_LINE" "$SSH_DIR/config"; then
  tmp="$(mktemp)"
  printf '%s\n\n' "$INC_LINE" | cat - "$SSH_DIR/config" > "$tmp" && mv "$tmp" "$SSH_DIR/config"
  ok "~/.ssh/config 상단에 Include 추가"
else
  ok "~/.ssh/config Include 이미 존재"
fi
chmod 600 "$SSH_DIR/config"

# ─────────────────────────────────────────────
# 6) 기본 셸을 zsh로 (선택)
# ─────────────────────────────────────────────
ZSH_PATH="$(command -v zsh || true)"
if [[ -n "$ZSH_PATH" ]] && [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
  warn "기본 셸이 zsh가 아닙니다 (현재: ${SHELL:-unknown})"
  echo "    변경하려면: chsh -s $ZSH_PATH"
fi

# ─────────────────────────────────────────────
# 6.5) auto-pull 주기 실행 (launchd on macOS / cron on Linux)
# ─────────────────────────────────────────────
# tracked repo들을 1시간마다 안전하게 fast-forward pull. 스크립트는 dirty/ahead/
# upstream-없음 repo를 건드리지 않는다 (scripts/auto-pull.sh 참고).
log "auto-pull 주기 실행 설정 중..."
AUTOPULL="$REPO_DIR/scripts/auto-pull.sh"
AUTOPULL_LOG="$HOME/.local/state/copilot/auto-pull.log"
mkdir -p "$(dirname "$AUTOPULL_LOG")"
if [[ ! -x "$AUTOPULL" ]]; then
  warn "auto-pull.sh 없음/실행불가 — 건너뜀"
elif [[ "$OS" == "Darwin" ]]; then
  LABEL="com.paryoja.copilot-autopull"
  PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$AUTOPULL</string>
  </array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><false/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StandardOutPath</key><string>$AUTOPULL_LOG</string>
  <key>StandardErrorPath</key><string>$AUTOPULL_LOG</string>
</dict>
</plist>
PLISTEOF
  launchctl unload "$PLIST" 2>/dev/null || true
  if launchctl load "$PLIST" 2>/dev/null; then
    ok "launchd auto-pull 등록 (1h): $LABEL"
  else
    warn "launchctl load 실패 — 수동 확인 필요: $PLIST"
  fi
elif [[ "$OS" == "Linux" ]]; then
  CRON_LINE="0 * * * * /bin/bash $AUTOPULL >/dev/null 2>&1"
  CRON_TAG="# copilot-autopull"
  CUR="$(crontab -l 2>/dev/null || true)"
  if printf '%s\n' "$CUR" | grep -qF "$AUTOPULL"; then
    ok "cron auto-pull 이미 등록됨"
  else
    { printf '%s\n' "$CUR"; printf '%s %s\n' "$CRON_LINE" "$CRON_TAG"; } | crontab - \
      && ok "cron auto-pull 등록 (매시 정각)" || warn "crontab 등록 실패"
  fi
fi

# ─────────────────────────────────────────────
# 7) 검증
# ─────────────────────────────────────────────
echo
log "검증:"
# set -e 상태라 실패가 install stamp(8단계)까지 막지 않도록 명시적으로 흡수한다.
bash "$REPO_DIR/check-symlinks.sh" || warn "symlink 검증에 실패 항목 있음 (위 출력 확인)"

# ─────────────────────────────────────────────
# 8) install stamp (적용 완료 커밋 기록)
# ─────────────────────────────────────────────
# 현재 HEAD 를 .git/installed-commit 에 남긴다 (untracked, 머신별).
# node-agent 가 이 값과 HEAD 를 비교해 "pull만 하고 install 안 함" 을 감지한다.
if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  STAMP_HEAD="$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true)"
  GIT_DIR="$(git -C "$REPO_DIR" rev-parse --git-dir 2>/dev/null || true)"
  if [[ -n "$STAMP_HEAD" && -n "$GIT_DIR" ]]; then
    case "$GIT_DIR" in /*) ;; *) GIT_DIR="$REPO_DIR/$GIT_DIR" ;; esac
    printf '%s\n' "$STAMP_HEAD" > "$GIT_DIR/installed-commit"
    ok "install stamp: ${STAMP_HEAD:0:12}"
  fi
fi

echo
ok "셋업 완료!"
echo
echo "다음 단계:"
echo "  1. 새 zsh 세션 시작:  exec zsh   (또는 재로그인)"
echo "  2. Copilot CLI 재시작 (hooks 적용)"
if [[ "$SERVER_MODE" != "1" ]]; then
  echo "  3. 터미널 폰트를 Nerd Font 로 변경 (선택, starship 아이콘 표시용)"
  echo "     - 추천: MesloLGS NF / JetBrainsMono Nerd Font / FiraCode Nerd Font"
  echo "     - https://www.nerdfonts.com/"
else
  echo "  3. daily status report: scripts/setup-status-report.sh (미셋업이면)"
fi
