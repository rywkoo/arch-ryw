#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

BASE_DIR="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)}"
PLUGIN_LIST="$BASE_DIR/restore_zsh.lst"
TARGET_USER="$(id -un)"
TARGET_HOME="$HOME"

command -v zsh >/dev/null 2>&1 || {
    echo "Zsh is not installed. The login shell cannot be changed." >&2
    exit 1
}
command -v sudo >/dev/null 2>&1 || {
    echo "sudo is unavailable. Cannot change the account login shell." >&2
    exit 1
}
command -v getent >/dev/null 2>&1 || {
    echo "getent is unavailable. Cannot verify the account login shell." >&2
    exit 1
}

ZSH_BIN="$(command -v zsh)"
[[ -x "$ZSH_BIN" ]] || { echo "Zsh executable is not executable: $ZSH_BIN" >&2; exit 1; }
[[ -f "$TARGET_HOME/.zshenv" ]] || { echo "Missing $TARGET_HOME/.zshenv. The bundled shell configuration was not deployed." >&2; exit 1; }
[[ -f "$TARGET_HOME/.config/zsh/.zshenv" ]] || { echo "Missing $TARGET_HOME/.config/zsh/.zshenv." >&2; exit 1; }
[[ -f "$TARGET_HOME/.config/zsh/.zshrc" ]] || { echo "Missing $TARGET_HOME/.config/zsh/.zshrc." >&2; exit 1; }

# Validate every installed Zsh startup/configuration file before changing the login shell.
SYNTAX_OK=1
while IFS= read -r -d '' file; do
    if ! zsh -n "$file"; then
        printf '[FAIL] Zsh syntax error: %s\n' "$file" >&2
        SYNTAX_OK=0
    fi
done < <(
    find "$TARGET_HOME/.config/zsh" -type f \
        \( -name '*.zsh' -o -name '.zshrc' -o -name '.zshenv' \) -print0
)
if ! zsh -n "$TARGET_HOME/.zshenv"; then
    printf '[FAIL] Zsh syntax error: %s\n' "$TARGET_HOME/.zshenv" >&2
    SYNTAX_OK=0
fi
if ((SYNTAX_OK == 0)); then
    echo "Zsh syntax validation failed. The current login shell was left unchanged." >&2
    exit 1
fi

# Add the exact executable path to /etc/shells if it is not already present.
if ! grep -qxF "$ZSH_BIN" /etc/shells; then
    printf '%s\n' "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
fi
grep -qxF "$ZSH_BIN" /etc/shells || {
    echo "Zsh could not be registered in /etc/shells." >&2
    exit 1
}

# Change the account shell as root so chsh does not fail on an interactive password prompt.
# usermod is a fallback for systems where sudo chsh is unavailable or restricted.
echo "Changing the login shell for account '$TARGET_USER' to '$ZSH_BIN'..."
if ! sudo chsh -s "$ZSH_BIN" "$TARGET_USER"; then
    echo "sudo chsh failed. Trying usermod as a fallback..."
    sudo usermod --shell "$ZSH_BIN" "$TARGET_USER"
fi

ACTUAL_SHELL="$(getent passwd "$TARGET_USER" | awk -F: '{print $7}')"
if [[ "$ACTUAL_SHELL" != "$ZSH_BIN" ]]; then
    printf 'Login shell verification failed. Expected %s, found %s\n' "$ZSH_BIN" "${ACTUAL_SHELL:-unknown}" >&2
    exit 1
fi
printf '[ OK ] Login shell changed and verified: %s\n' "$ACTUAL_SHELL"

# Shell selection is now complete. Plugin downloads are optional and cannot undo it.
PLUGIN_FAILURES=()
if ! command -v git >/dev/null 2>&1; then
    echo "Git is unavailable. Skipping Oh My Zsh and plugin downloads; the Zsh login shell remains configured." >&2
    exit 1
fi

if [[ ! -f "$TARGET_HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    echo "Downloading the Oh My Zsh installer..."
    OMZ_INSTALLER="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
        echo "Could not download the Oh My Zsh installer. Zsh login shell is configured, but Oh My Zsh features are unavailable." >&2
        exit 1
    }
    echo "Installing Oh My Zsh..."
    if ! RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$OMZ_INSTALLER" --unattended; then
        echo "Oh My Zsh installation failed. Zsh login shell is configured, but Oh My Zsh features are unavailable." >&2
        exit 1
    fi
fi

if [[ -f "$TARGET_HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    ZSH_CUSTOM="$TARGET_HOME/.oh-my-zsh/custom/plugins"
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
        [[ -d "$target" ]]
    }

    try_plugin() {
        local name="$1"
        local url="$2"
        if install_plugin "$name" "$url"; then
            printf '[ OK ] plugin: %s\n' "$name"
        else
            printf '[SKIP] plugin download failed: %s\n' "$name" >&2
            PLUGIN_FAILURES+=("$name")
        fi
    }

    try_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
    try_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
    try_plugin zsh-256color https://github.com/chrissicool/zsh-256color.git

    if [[ -f "$PLUGIN_LIST" ]]; then
        while IFS= read -r url || [[ -n "$url" ]]; do
            [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
            plugin_name="$(basename "$url" .git)"
            case "$plugin_name" in
                zsh-syntax-highlighting|zsh-autosuggestions|zsh-256color)
                    continue
                    ;;
            esac
            try_plugin "$plugin_name" "$url"
        done < "$PLUGIN_LIST"
    fi
else
    echo "Oh My Zsh is unavailable. The login shell is configured, but plugins were skipped." >&2
    exit 1
fi

if ((${#PLUGIN_FAILURES[@]} > 0)); then
    printf '\nSome Zsh plugins could not be downloaded:\n' >&2
    printf '  - %s\n' "${PLUGIN_FAILURES[@]}" >&2
    exit 1
fi

echo "Zsh login shell, Oh My Zsh, and configured plugins are ready."
echo "The new login shell takes effect in newly opened login sessions; log out and back in."
