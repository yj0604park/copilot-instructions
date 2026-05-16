#!/bin/bash
# Check if Copilot config files are properly symlinked

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"

FILES=(
  "$COPILOT_HOME/copilot-instructions.md"
  "$COPILOT_HOME/hooks/notification.json"
  "$COPILOT_HOME/hooks/scripts/notify.sh"
  "$COPILOT_HOME/hooks/scripts/notify-event.sh"
  "$HOME/.tmux.conf"
  "$HOME/.vimrc"
  "$HOME/.zshrc"
  "$HOME/.config/starship.toml"
)

OK=0
NG=0

for f in "${FILES[@]}"; do
  if [ -L "$f" ]; then
    target=$(readlink "$f")
    if [[ "$target" == *"$REPO_DIR"* ]] || [[ "$target" == *"copilot-instructions"* ]]; then
      echo "✅ $f → $target"
    else
      echo "⚠️  $f → $target (unexpected target)"
      ((NG++))
    fi
    ((OK++))
  elif [ -f "$f" ]; then
    echo "❌ $f (regular file, not symlink)"
    ((NG++))
  else
    echo "⏭️  $f (not found)"
  fi
done

echo ""
echo "Result: $OK symlinks OK, $NG issues"
[ "$NG" -eq 0 ] && exit 0 || exit 1
