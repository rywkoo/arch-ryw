#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

BASE_DIR="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)}"
PLUGIN_LIST="$BASE_DIR/restore_zsh.lst"
command -v zsh >/dev/null 2>&1 || { echo "zsh is not installed; skipping Zsh setup." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git is not installed; skipping Zsh plugin setup." >&2; exit 1; }

ZSHRC="$HOME/.config/zsh/.zshrc"
[[ -f "$ZSHRC" ]] || { echo "Expected Zsh configuration is missing: $ZSHRC" >&2; exit 1; }

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    echo "Installing Oh My Zsh..."
    if ! RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended; then
        echo "Oh My Zsh installation failed. Skipping the rest of Zsh setup." >&2
        exit 1
    fi
fi

[[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] || { echo "Oh My Zsh files are missing." >&2; exit 1; }
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$ZSH_CUSTOM"
FAILED_PLUGINS=()

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
    [[ -d "$target" ]]
}

try_plugin() {
    local name="$1"
    local url="$2"
    if install_plugin "$name" "$url"; then
        printf '[ OK ] plugin: %s\n' "$name"
    else
        printf '[SKIP] plugin failed: %s\n' "$name" >&2
        FAILED_PLUGINS+=("$name")
    fi
}

try_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
try_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
try_plugin zsh-256color https://github.com/chrissicool/zsh-256color.git

if [[ -f "$PLUGIN_LIST" ]]; then
    while IFS= read -r url || [[ -n "$url" ]]; do
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
        plugin_name="$(basename "$url" .git)"
        try_plugin "$plugin_name" "$url"
    done < "$PLUGIN_LIST"
fi

ZSH_BIN="$(command -v zsh)"
if ! grep -qxF "$ZSH_BIN" /etc/shells; then
    printf '%s\n' "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null || {
        echo "Could not add Zsh to /etc/shells." >&2
        exit 1
    }
fi

SYNTAX_OK=1
if ! zsh -n "$HOME/.zshenv"; then
    echo "The home .zshenv contains a syntax error. Keeping the current login shell." >&2
    SYNTAX_OK=0
fi
while IFS= read -r -d '' file; do
    if ! zsh -n "$file"; then
        echo "Zsh syntax error in: $file" >&2
        SYNTAX_OK=0
    fi
done < <(find "$HOME/.config/zsh" -type f \( -name '*.zsh' -o -name '.zshrc' -o -name '.zshenv' \) -print0)

if ((SYNTAX_OK)); then
    if ! getent passwd "$USER" | awk -F: -v shell="$ZSH_BIN" '$7 == shell { found=1 } END { exit !found }'; then
        chsh -s "$ZSH_BIN" || {
            echo "Could not change the default login shell to Zsh." >&2
            exit 1
        }
    fi
else
    exit 1
fi

if ((${#FAILED_PLUGINS[@]} > 0)); then
    printf '\nSome plugins were skipped:\n' >&2
    printf '  - %s\n' "${FAILED_PLUGINS[@]}" >&2
    exit 1
fi

echo "Oh My Zsh, plugins, and Zsh syntax checks completed."
