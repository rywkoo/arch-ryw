#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACMAN_LIST="$SCRIPT_DIR/pac_1.lst"
AUR_LIST="$SCRIPT_DIR/pac_2.lst"

for manifest in "$PACMAN_LIST" "$AUR_LIST"; do
    [[ -f "$manifest" ]] || { printf 'Package manifest missing: %s\n' "$manifest" >&2; exit 1; }
done

mapfile -t PACMAN_PACKAGES < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$PACMAN_LIST" | awk '!seen[$0]++')
mapfile -t AUR_PACKAGES < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$AUR_LIST" | awk '!seen[$0]++')

FAILED_PACKAGES=()

install_official_packages() {
    if ((${#PACMAN_PACKAGES[@]} == 0)); then
        echo "No official packages are listed."
        return 0
    fi

    echo "Attempting to install ${#PACMAN_PACKAGES[@]} official packages together..."
    if sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"; then
        return 0
    fi

    echo "The grouped official package install failed. Retrying packages individually; failures will be skipped." >&2
    local package
    for package in "${PACMAN_PACKAGES[@]}"; do
        if sudo pacman -S --needed --noconfirm "$package"; then
            printf '[ OK ] %s\n' "$package"
        else
            printf '[SKIP] %s could not be installed.\n' "$package" >&2
            FAILED_PACKAGES+=("official:$package")
        fi
    done
}

install_aur_packages() {
    if ((${#AUR_PACKAGES[@]} == 0)); then
        echo "No AUR packages are listed."
        return 0
    fi
    if ! command -v yay >/dev/null 2>&1; then
        echo "yay is unavailable. Skipping AUR packages:" >&2
        printf '  - %s\n' "${AUR_PACKAGES[@]}" >&2
        for package in "${AUR_PACKAGES[@]}"; do
            FAILED_PACKAGES+=("AUR:$package (yay unavailable)")
        done
        return 0
    fi

    echo "Attempting to install ${#AUR_PACKAGES[@]} AUR packages together..."
    if yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"; then
        return 0
    fi

    echo "The grouped AUR package install failed. Retrying packages individually; failures will be skipped." >&2
    local package
    for package in "${AUR_PACKAGES[@]}"; do
        if yay -S --needed --noconfirm "$package"; then
            printf '[ OK ] AUR %s\n' "$package"
        else
            printf '[SKIP] AUR %s could not be installed.\n' "$package" >&2
            FAILED_PACKAGES+=("AUR:$package")
        fi
    done
}

install_official_packages
install_aur_packages

if ((${#FAILED_PACKAGES[@]} > 0)); then
    printf '\nThe following packages could not be installed and were skipped:\n' >&2
    printf '  - %s\n' "${FAILED_PACKAGES[@]}" >&2
    exit 1
fi

echo "All listed application packages were installed."
