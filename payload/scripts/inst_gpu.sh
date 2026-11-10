#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v lspci >/dev/null 2>&1; then
    echo "lspci is unavailable. Skipping automatic GPU driver detection."
    exit 0
fi

GPU_INFO="$(lspci -nn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)"
if [[ -z "$GPU_INFO" ]]; then
    echo "No GPU information was returned. Skipping automatic driver installation."
    exit 0
fi
printf '%s\n' "$GPU_INFO"

if grep -Eqi 'NVIDIA' <<<"$GPU_INFO"; then
    if grep -Eqi 'RTX 20[0-9]{2}|RTX 30[0-9]{2}|RTX 40[0-9]{2}|RTX 50[0-9]{2}|GTX 16[0-9]{2}' <<<"$GPU_INFO"; then
        if pacman -Q linux >/dev/null 2>&1; then
            sudo pacman -S --needed --noconfirm nvidia-open nvidia-utils nvidia-prime egl-wayland linux-headers
        elif pacman -Q linux-lts >/dev/null 2>&1; then
            sudo pacman -S --needed --noconfirm nvidia-open-lts nvidia-utils nvidia-prime egl-wayland linux-lts-headers
        else
            echo "NVIDIA GPU detected, but no standard linux/linux-lts kernel package was found. Skipping automatic driver selection."
        fi
    else
        echo "NVIDIA GPU detected but not positively matched to the open driver branch. Skipping automatic driver changes."
    fi
fi

if grep -Eqi 'Intel' <<<"$GPU_INFO"; then
    sudo pacman -S --needed --noconfirm vulkan-intel intel-media-driver
fi
if grep -Eqi 'AMD|Advanced Micro Devices' <<<"$GPU_INFO"; then
    sudo pacman -S --needed --noconfirm vulkan-radeon
fi
