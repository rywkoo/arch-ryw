#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
EXTRA_DIR="$PROJECT_ROOT/extra"
[[ -d "$EXTRA_DIR/.config" ]] || { echo "Missing dotfile payload: $EXTRA_DIR/.config" >&2; exit 1; }
STATE="$HOME/.local/state/ryw-installer/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$STATE" "$HOME/Pictures/wallpaper" "$HOME/Pictures/Screenshots"
# Backup the entire existing config before replacing it, including files not in this bundle.
if [[ -e "$HOME/.config" ]]; then
  mv "$HOME/.config" "$STATE/config-before-final-$STAMP"
fi
mkdir -p "$HOME/.config"
cp -a "$EXTRA_DIR/.config/." "$HOME/.config/"
# Hyprlock/Hyprland config values are written with a portable $HOME token; materialize it here.
for config_file in "$HOME/.config/hypr/hyprlock.conf" "$HOME/.config/hypr/workflows/shaders.conf"; do
  if [[ -f "$config_file" ]]; then
    sed -i "s|\\\$HOME|$HOME|g" "$config_file"
  fi
done
for f in .zshenv .p10k.zsh; do
  if [[ -f "$EXTRA_DIR/$f" ]]; then
    [[ ! -e "$HOME/$f" ]] || cp -a "$HOME/$f" "$STATE/$f-before-$STAMP"
    cp -a "$EXTRA_DIR/$f" "$HOME/$f"
  fi
done
# Set machine-dependent paths at install time.
printf 'file://%s/Downloads Downloads\nfile://%s/Pictures Pictures\n' "$HOME" "$HOME" > "$HOME/.config/gtk-3.0/bookmarks"
printf '%s\n' "$HOME/.config/waybar/Theme/My Theme" > "$HOME/.config/waybar/.current-theme"
# Keep wallpaper images already on the machine; only add files that are not there.
WALLPAPER_SOURCES=()
[[ -d "$EXTRA_DIR/wallpaper" ]] && WALLPAPER_SOURCES+=("$EXTRA_DIR/wallpaper")
[[ -d "$EXTRA_DIR/.config/hypr/wallpaper" ]] && WALLPAPER_SOURCES+=("$EXTRA_DIR/.config/hypr/wallpaper")
if ((${#WALLPAPER_SOURCES[@]})); then
  find "${WALLPAPER_SOURCES[@]}" -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.avif' \) -print0 |
    while IFS= read -r -d '' image; do
      target="$HOME/Pictures/wallpaper/$(basename "$image")"
      [[ -e "$target" ]] || cp -a "$image" "$target"
    done
fi
find "$HOME/.config" -type f -name '*.sh' -exec chmod u+x {} +
fc-cache -f >/dev/null
printf 'Dotfiles and wallpapers restored. Previous .config is backed up under %s\n' "$STATE"
