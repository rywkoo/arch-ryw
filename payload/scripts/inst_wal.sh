#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PAYLOAD_DIR="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)}"
EXTRA_DIR="$PAYLOAD_DIR/extra"
CONFIG_SOURCE="$EXTRA_DIR/.config"
STATE="$HOME/.local/state/ryw-installer/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
CONFIG_BACKUP="$STATE/config-before-final-$STAMP"
STAGING="$HOME/.config.ryw-staging-$STAMP"
ROLLBACK_NEEDED=0

[[ -d "$CONFIG_SOURCE/hypr" ]] || { echo "Missing complete configuration: $CONFIG_SOURCE/hypr" >&2; exit 1; }
[[ -f "$CONFIG_SOURCE/hypr/hyprland.lua" ]] || { echo "Missing Hyprland Lua entry point." >&2; exit 1; }
[[ -f "$CONFIG_SOURCE/hypr/keybinds.lua" ]] || { echo "Missing Hyprland keybindings." >&2; exit 1; }
[[ -d "$CONFIG_SOURCE/waybar" ]] || { echo "Missing Waybar configuration." >&2; exit 1; }
[[ -d "$CONFIG_SOURCE/quickshell" ]] || { echo "Missing Quickshell configuration." >&2; exit 1; }
[[ -d "$CONFIG_SOURCE/rofi" ]] || { echo "Missing Rofi configuration." >&2; exit 1; }

mkdir -p "$STATE" "$HOME/Pictures/wallpaper" "$HOME/Pictures/Screenshots"
rm -rf "$STAGING"
mkdir -p "$STAGING"

rollback() {
    local status=$?
    if ((ROLLBACK_NEEDED)); then
        echo "Configuration copy failed. Restoring the previous ~/.config..." >&2
        rm -rf "$HOME/.config"
        if [[ -d "$CONFIG_BACKUP" ]]; then
            mv "$CONFIG_BACKUP" "$HOME/.config"
        fi
    fi
    rm -rf "$STAGING"
    exit "$status"
}
trap rollback ERR

echo "Staging the exact bundled ~/.config tree..."
cp -a "$CONFIG_SOURCE/." "$STAGING/"
[[ -f "$STAGING/hypr/keybinds.lua" ]]
[[ -f "$STAGING/waybar/config.jsonc" ]]
[[ -f "$STAGING/quickshell/shell.qml" ]]
[[ -f "$STAGING/rofi/config.rasi" ]]

# Materialize portable HOME placeholders without changing unrelated files.
for config_file in "$STAGING/hypr/hyprlock.conf" "$STAGING/hypr/workflows/shaders.conf"; do
    if [[ -f "$config_file" ]]; then
        sed -i "s|\\\$HOME|$HOME|g" "$config_file"
    fi
done

# Preserve the existing configuration as one complete, timestamped backup.
if [[ -e "$HOME/.config" ]]; then
    mv "$HOME/.config" "$CONFIG_BACKUP"
fi
ROLLBACK_NEEDED=1
mv "$STAGING" "$HOME/.config"
ROLLBACK_NEEDED=0
trap - ERR

# Back up shell entry files individually before replacing them.
for file in .zshenv .p10k.zsh; do
    if [[ -f "$EXTRA_DIR/$file" ]]; then
        if [[ -e "$HOME/$file" ]]; then
            cp -a "$HOME/$file" "$STATE/$file-before-$STAMP"
        fi
        cp -a "$EXTRA_DIR/$file" "$HOME/$file"
    fi
done

# Generate machine-specific GTK bookmarks and selected Waybar theme marker.
mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/waybar"
printf 'file://%s/Downloads Downloads\nfile://%s/Pictures Pictures\n' "$HOME" "$HOME" > "$HOME/.config/gtk-3.0/bookmarks"
printf '%s\n' "$HOME/.config/waybar/Theme/My Theme" > "$HOME/.config/waybar/.current-theme"

# Add bundled wallpapers without overwriting files already on the machine.
WALLPAPER_SOURCES=()
[[ -d "$EXTRA_DIR/wallpaper" ]] && WALLPAPER_SOURCES+=("$EXTRA_DIR/wallpaper")
[[ -d "$CONFIG_SOURCE/hypr/wallpaper" ]] && WALLPAPER_SOURCES+=("$CONFIG_SOURCE/hypr/wallpaper")
if ((${#WALLPAPER_SOURCES[@]})); then
    while IFS= read -r -d '' image; do
        target="$HOME/Pictures/wallpaper/$(basename "$image")"
        [[ -e "$target" ]] || cp -a "$image" "$target"
    done < <(find "${WALLPAPER_SOURCES[@]}" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.avif' \) -print0)
fi

find "$HOME/.config" -type f -name '*.sh' -exec chmod u+x {} +
printf 'Full RyW configuration installed. Previous configuration backup: %s\n' "$CONFIG_BACKUP"
