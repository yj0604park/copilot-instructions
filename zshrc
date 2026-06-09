# ─────────────────────────────────────────────
# PATH
# ─────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# macOS 전용 경로 (Homebrew)
if [[ "$OSTYPE" == darwin* ]]; then
  [[ -d "/usr/local/opt/libpq/bin" ]] && export PATH="/usr/local/opt/libpq/bin:$PATH"
  if [[ -d "/opt/homebrew/opt/openjdk@17" ]]; then
    export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
    export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
  fi
fi

# ─────────────────────────────────────────────
# oh-my-zsh (theme off — starship 사용)
# 외부 plugins (zsh-autosuggestions / zsh-syntax-highlighting)는
# install.sh가 $ZSH_CUSTOM/plugins/ 에 clone 해 둠.
# zsh-syntax-highlighting 은 반드시 마지막에 둘 것.
# ─────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# 외부 zsh-completions (oh-my-zsh가 모르는 것 추가)
for d in \
  "$(brew --prefix 2>/dev/null)/share/zsh-completions" \
  /usr/local/share/zsh-completions \
  /usr/share/zsh-completions \
  "$HOME/.zsh-completions/src"; do
  [[ -d "$d" ]] && FPATH="$d:$FPATH"
done

# ─────────────────────────────────────────────
# Prompt: starship (oh-my-zsh 다음에 와야 PROMPT 덮어씀)
# ─────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init zsh)"
fi

# ─────────────────────────────────────────────
# Key bindings (Home / End / Ctrl+← → / Option+← →)
# oh-my-zsh 다음에 와야 override 가능
# ─────────────────────────────────────────────
bindkey "^[[H" beginning-of-line
bindkey "^[OH" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[OF" end-of-line

bindkey "^[[1;5D" backward-word
bindkey "^[[5D"   backward-word
bindkey "^[[1;5C" forward-word
bindkey "^[[5C"   forward-word

# Option+Arrow (iTerm2 + tmux)
bindkey "^[[1;3D" backward-word
bindkey "^[[1;3C" forward-word
bindkey "^[b"     backward-word
bindkey "^[f"     forward-word

# ─────────────────────────────────────────────
# fzf
# ─────────────────────────────────────────────
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]   && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# ─────────────────────────────────────────────
# atuin (shell history sync: Ctrl+R 대체)
# fzf보다 먼저 init하면 Ctrl+R을 atuin이 가져감
# ─────────────────────────────────────────────
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

# ─────────────────────────────────────────────
# zoxide (smart cd: z <keyword>, zi for interactive)
# ─────────────────────────────────────────────
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# ─────────────────────────────────────────────
# Aliases
# ─────────────────────────────────────────────
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias lg='lazygit'

# 모던 CLI 대체
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons'
  alias ll='eza -alh --icons --git'
  alias la='eza -A --icons'
  alias tree='eza --tree --icons'
else
  alias ll='ls -alh'
  alias la='ls -A'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# ─────────────────────────────────────────────
# Language toolchains
# ─────────────────────────────────────────────
# Rust
[[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# fnm (Node version manager)
FNM_PATH="$HOME/Library/Application Support/fnm"
if [[ -d "$FNM_PATH" ]]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env)"
fi

# Misc
stty -ixon
# export COMPOSE_FILE=local.yml

# Copilot CLI defaults
copilot() {
  command copilot --allow-all --remote "$@"
}

# ─────────────────────────────────────────────
# SDKMAN — MUST BE AT THE END OF THE FILE
# ─────────────────────────────────────────────
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

[[ -s "$HOME/.atuin/bin/env" ]] && . "$HOME/.atuin/bin/env"
