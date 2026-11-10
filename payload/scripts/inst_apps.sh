#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PACMAN_LIST="$SCRIPT_DIR/pac_1.lst"
AUR_LIST="$SCRIPT_DIR/pac_2.lst"

for manifest in "$PACMAN_LIST" "$AUR_LIST"; do
    [[ -f "$manifest" ]] || { printf 'Package manifest missing: %s\n' "$manifest" >&2; exit 1; }
done

mapfile -t RAW_PACMAN_PACKAGES < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$PACMAN_LIST" | awk '!seen[$0]++')
mapfile -t AUR_PACKAGES < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$AUR_LIST" | awk '!seen[$0]++')

PACMAN_PACKAGES=()
OPTIONAL_SKIPS=()
FAILED_PACKAGES=()

# pipewire-jack and jack2 provide competing JACK implementations.
# Do not remove a user's existing JACK2 stack without explicit approval.
if pacman -Q jack2 >/dev/null 2>&1 || pacman -Q jack2-dbus >/dev/null 2>&1; then
    echo "[SKIP] pipewire-jack: an existing jack2/jack2-dbus package was detected."
    echo "       Existing JACK applications may depend on it; the installer will not remove it automatically."
    echo "       To migrate later, inspect reverse dependencies first, then replace jack2 with pipewire-jack."
    OPTIONAL_SKIPS+=("pipewire-jack (existing JACK2 installation preserved)")
    for package in "${RAW_PACMAN_PACKAGES[@]}"; do
        [[ "$package" == "pipewire-jack" ]] || PACMAN_PACKAGES+=("$package")
    done
else
    PACMAN_PACKAGES=("${RAW_PACMAN_PACKAGES[@]}")
fi

install_pywal_fallback() {
    echo "The official python-pywal package did not install. Trying the Pywal 16 AUR fork..."
    if ! command -v yay >/dev/null 2>&1; then
        echo "yay is unavailable; cannot try the python-pywal16 AUR fallback." >&2
        return 1
    fi
    if yay -S --needed --noconfirm python-pywal16; then
        if command -v wal >/dev/null 2>&1; then
            echo "[ OK ] Pywal fallback installed as python-pywal16."
            return 0
        fi
        echo "python-pywal16 installation returned success, but the wal command was not found." >&2
    fi
    return 1
}

install_official_packages() {
    if ((${#PACMAN_PACKAGES[@]} == 0)); then
        echo "No official packages remain in the package manifest."
        return 0
    fi

    echo "Attempting to install ${#PACMAN_PACKAGES[@]} official packages together..."
    if sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"; then
        return 0
    fi

    echo "The grouped official package install failed. Retrying packages individually."
    echo "A failure in one package will not prevent the remaining packages from being attempted."
    local package
    for package in "${PACMAN_PACKAGES[@]}"; do
        if sudo pacman -S --needed --noconfirm "$package"; then
            printf '[ OK ] %s\n' "$package"
        else
            if [[ "$package" == "python-pywal" ]]; then
                if install_pywal_fallback; then
                    continue
                fi
                FAILED_PACKAGES+=("official:python-pywal (python-pywal16 fallback also failed)")
            else
                printf '[SKIP] %s could not be installed.\n' "$package" >&2
                FAILED_PACKAGES+=("official:$package")
            fi
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

    echo "The grouped AUR package install failed. Retrying packages individually."
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

if ((${#OPTIONAL_SKIPS[@]} > 0)); then
    printf '\nOptional packages intentionally skipped:\n'
    printf '  - %s\n' "${OPTIONAL_SKIPS[@]}"
fi

if ((${#FAILED_PACKAGES[@]} > 0)); then
    printf '\nThe following packages could not be installed and were skipped:\n' >&2
    printf '  - %s\n' "${FAILED_PACKAGES[@]}" >&2
    exit 1
fi

echo "All applicable package installation attempts completed."
