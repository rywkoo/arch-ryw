#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACMAN_LIST="$SCRIPT_DIR/pac_1.lst"
AUR_LIST="$SCRIPT_DIR/pac_2.lst"
[[ -f "$PACMAN_LIST" && -f "$AUR_LIST" ]] || { echo "Package manifest missing." >&2; exit 1; }
mapfile -t PACMAN_PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$PACMAN_LIST" | awk '!seen[$0]++')
mapfile -t AUR_PACKAGES < <(grep -Ev '^[[:space:]]*(#|$)' "$AUR_LIST" | awk '!seen[$0]++')
if ((${#PACMAN_PACKAGES[@]})); then
  echo "Installing ${#PACMAN_PACKAGES[@]} official packages..."
  sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
fi
if ((${#AUR_PACKAGES[@]})); then
  command -v yay >/dev/null 2>&1 || { echo "AUR packages listed but yay is unavailable." >&2; exit 1; }
  yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
fi
echo "Package installation complete."
