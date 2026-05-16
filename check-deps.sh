#!/usr/bin/env bash
# 환경 설정에 필요한 프로그램 설치 여부 확인
set -uo pipefail

ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
miss() { printf "\033[1;31m✗\033[0m %s ← %s\n" "$1" "$2"; MISSING+=("$1"); }

MISSING=()

check() {
  local cmd="$1" hint="${2:-}"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd ($(command -v "$cmd"))"
  else
    miss "$cmd" "${hint:-설치 필요}"
  fi
}

echo "── 필수 프로그램 ──"
check zsh        "brew install zsh"
check tmux       "brew install tmux"
check starship   "brew install starship 또는 https://starship.rs"
check fzf        "brew install fzf"
check jq         "brew install jq"
check git        "brew install git"
check curl       "brew install curl"

echo
echo "── 선택 프로그램 ──"
check gh         "brew install gh (GitHub CLI)"
check atuin      "brew install atuin (shell history sync)"
check node       "brew install node"
check python3    "brew install python3"
check vim        "brew install vim"

echo
echo "── zsh 플러그인 ──"
ZSH_AUTO="$(brew --prefix 2>/dev/null)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
if [[ -f "$ZSH_AUTO" ]]; then
  ok "zsh-autosuggestions"
else
  miss "zsh-autosuggestions" "brew install zsh-autosuggestions"
fi

ZSH_COMP="$(brew --prefix 2>/dev/null)/share/zsh-completions"
if [[ -d "$ZSH_COMP" ]]; then
  ok "zsh-completions"
else
  miss "zsh-completions" "brew install zsh-completions"
fi

echo
echo "── Nerd Font 확인 ──"
if fc-list 2>/dev/null | grep -qi "nerd\|meslo.*nf\|jetbrains.*nf\|fira.*nf"; then
  ok "Nerd Font 감지됨"
elif [[ -d "$HOME/Library/Fonts" ]] && ls "$HOME/Library/Fonts" 2>/dev/null | grep -qi "nerd\|meslo.*nf\|jetbrains.*nf\|fira.*nf"; then
  ok "Nerd Font 감지됨 (~/Library/Fonts)"
else
  miss "Nerd Font" "https://www.nerdfonts.com/ 에서 설치 (starship 아이콘용)"
fi

echo
if [[ ${#MISSING[@]} -eq 0 ]]; then
  printf "\033[1;32m모든 의존성 설치 확인 완료!\033[0m\n"
else
  printf "\033[1;33m미설치 항목 %d개:\033[0m %s\n" "${#MISSING[@]}" "${MISSING[*]}"
  exit 1
fi
