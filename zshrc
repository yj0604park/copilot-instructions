
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

export PATH="$HOME/.local/bin:$PATH"

# zsh-autosuggestions
source /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-completions
FPATH=/usr/local/share/zsh-completions:$FPATH
autoload -Uz compinit && compinit

# fzf
source <(fzf --zsh)
