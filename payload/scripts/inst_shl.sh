#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

BASE_DIR="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)}"
PLUGIN_LIST="$BASE_DIR/restore_zsh.lst"

command -v zsh >/dev/null 2>&1 || { echo "zsh is not installed." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is not installed." >&2; exit 1; }
[[ -f "$HOME/.config/zsh/.zshrc" ]] || { echo "The full Zsh configuration has not been installed." >&2; exit 1; }

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
fi
[[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] || { echo "Oh My Zsh installation could not be verified." >&2; exit 1; }

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$ZSH_CUSTOM"

install_plugin() {
    local name="$1"
    local url="$2"
    local target="$ZSH_CUSTOM/$name"

    if [[ -d "$target/.git" ]]; then
        git -C "$target" pull --ff-only
    elif [[ -e "$target" ]]; then
        echo "Plugin target exists but is not a Git repository: $target" >&2
        return 1
    else
        git clone --depth 1 "$url" "$target"
    fi
    [[ -d "$target" ]] || { echo "Plugin installation failed: $name" >&2; return 1; }
}

install_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
install_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
install_plugin zsh-256color https://github.com/chrissicool/zsh-256color.git

if [[ -f "$PLUGIN_LIST" ]]; then
    while IFS= read -r url || [[ -n "$url" ]]; do
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
        plugin_name="$(basename "$url" .git)"
        install_plugin "$plugin_name" "$url"
    done < "$PLUGIN_LIST"
fi

ZSH_BIN="$(command -v zsh)"
grep -qxF "$ZSH_BIN" /etc/shells || printf '%s\n' "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
if ! getent passwd "$USER" | awk -F: -v shell="$ZSH_BIN" '$7 == shell { found=1 } END { exit !found }'; then
    chsh -s "$ZSH_BIN"
fi

zsh -n "$HOME/.zshenv"
while IFS= read -r -d '' file; do
    zsh -n "$file"
done < <(find "$HOME/.config/zsh" -type f \( -name '*.zsh' -o -name '.zshrc' -o -name '.zshenv' \) -print0)

printf 'Oh My Zsh, plugins, and Zsh syntax checks completed.\n'
printf 'Log out and back in to use Zsh as your login shell.\n'
