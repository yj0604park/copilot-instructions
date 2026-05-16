#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
export PATH="/usr/local/opt/libpq/bin:$PATH"

bindkey "^[[H" beginning-of-line
bindkey "^[OH" beginning-of-line

bindkey "^[[F" end-of-line
bindkey "^[OF" end-of-line

bindkey "^[[1;5D" backward-word  
bindkey "^[[5D" backward-word  

bindkey "^[[1;5C" forward-word  
bindkey "^[[5C" forward-word  

# Option+Arrow (iTerm2 + tmux)
bindkey "^[[1;3D" backward-word
bindkey "^[[1;3C" forward-word
bindkey "^[b" backward-word
bindkey "^[f" forward-word

export PATH="$HOME/.local/bin:$PATH"

# terminal title: show pwd (precmd) and running command (preexec)
precmd() { print -Pn "\e]0;%~\a" }
preexec() { print -Pn "\e]0;%~ ❯ $1\a" }

# starship prompt
if command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init zsh)"
fi

# zsh-autosuggestions
for f in \
  "$(brew --prefix 2>/dev/null)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  [[ -f "$f" ]] && source "$f" && break
done

# zsh-completions
for d in \
  "$(brew --prefix 2>/dev/null)/share/zsh-completions" \
  /usr/local/share/zsh-completions \
  /usr/share/zsh-completions \
  "$HOME/.zsh-completions/src"; do
  [[ -d "$d" ]] && FPATH="$d:$FPATH"
done
autoload -Uz compinit && compinit -u

# fzf
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi
