#!/usr/bin/env bash
set -Eeuo pipefail
BASE_DIR="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
PLUGIN_LIST="$BASE_DIR/restore_zsh.lst"
command -v zsh >/dev/null || { echo "zsh is not installed." >&2; exit 1; }
command -v git >/dev/null || { echo "git is not installed." >&2; exit 1; }
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
fi
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$ZSH_CUSTOM"
install_plugin() {
  local name="$1" url="$2" target="$ZSH_CUSTOM/$1"
  if [[ -d "$target/.git" ]]; then git -C "$target" pull --ff-only || true
  else git clone --depth=1 "$url" "$target"; fi
}
install_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
install_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
install_plugin zsh-256color https://github.com/chrissicool/zsh-256color.git
if [[ -f "$PLUGIN_LIST" ]]; then
  while IFS= read -r url; do
    [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
    install_plugin "$(basename "$url" .git)" "$url"
  done < "$PLUGIN_LIST"
fi
ZSHRC="$HOME/.config/zsh/.zshrc"
[[ -f "$ZSHRC" ]] || { echo "Expected Zsh config missing: $ZSHRC" >&2; exit 1; }
# Source validation catches malformed configuration before changing the login shell.
zsh -n "$HOME/.zshenv"
while IFS= read -r -d '' file; do
  zsh -n "$file"
done < <(find "$HOME/.config/zsh" -type f \( -name '*.zsh' -o -name '.zshrc' -o -name '.zshenv' \) -print0)
ZSH_BIN="$(command -v zsh)"
if ! getent passwd "$USER" | awk -F: -v s="$ZSH_BIN" '$7 == s { found=1 } END { exit !found }'; then
  chsh -s "$ZSH_BIN"
fi
if ! grep -qE '^[[:space:]]*Color([[:space:]]|$)' /etc/pacman.conf; then
  sudo sed -i '/^[[:space:]]*#Color/a ILoveCandy' /etc/pacman.conf
fi
printf 'Zsh configured. Log out and back in to use it as your login shell.\n'
