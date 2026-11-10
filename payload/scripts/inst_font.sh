#!/usr/bin/env bash
set -Eeuo pipefail

FONT_PACKAGES=(
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    ttf-dejavu
    ttf-liberation
    ttf-jetbrains-mono-nerd
    ttf-firacode-nerd
    otf-font-awesome
)
FAILED_FONTS=()

echo "Attempting to install all font packages together..."
if ! sudo pacman -S --needed --noconfirm "${FONT_PACKAGES[@]}"; then
    echo "Grouped font installation failed. Retrying each font package individually." >&2
    for package in "${FONT_PACKAGES[@]}"; do
        if sudo pacman -S --needed --noconfirm "$package"; then
            printf '[ OK ] %s\n' "$package"
        else
            printf '[SKIP] %s could not be installed.\n' "$package" >&2
            FAILED_FONTS+=("$package")
        fi
    done
fi

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f || {
        echo "Font cache refresh failed." >&2
        FAILED_FONTS+=("font-cache")
    }
else
    echo "fc-cache is unavailable. Skipping font cache refresh." >&2
    FAILED_FONTS+=("font-cache")
fi

if ((${#FAILED_FONTS[@]} > 0)); then
    printf '\nSkipped font items:\n' >&2
    printf '  - %s\n' "${FAILED_FONTS[@]}" >&2
    exit 1
fi
echo "Font installation and font-cache refresh complete."
