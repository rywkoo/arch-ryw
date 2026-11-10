#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACMAN_LIST="$SCRIPT_DIR/pac_1.lst"
AUR_LIST="$SCRIPT_DIR/pac_2.lst"

for manifest in "$PACMAN_LIST" "$AUR_LIST"; do
    [[ -f "$manifest" ]] || { printf 'Package manifest missing: %s\n' "$manifest" >&2; exit 1; }
done
command -v pacman >/dev/null 2>&1 || { echo "pacman is required." >&2; exit 1; }

mapfile -t PACMAN_PACKAGES < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$PACMAN_LIST" | awk '!seen[$0]++')
mapfile -t AUR_PACKAGES < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$AUR_LIST" | awk '!seen[$0]++')

if ((${#PACMAN_PACKAGES[@]})); then
    printf 'Installing %d official repository packages...\n' "${#PACMAN_PACKAGES[@]}"
    sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
fi

if ((${#AUR_PACKAGES[@]})); then
    command -v yay >/dev/null 2>&1 || { echo "AUR packages are listed, but yay is unavailable." >&2; exit 1; }
    printf 'Installing %d AUR packages...\n' "${#AUR_PACKAGES[@]}"
    yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
fi

printf 'Application package installation complete.\n'
