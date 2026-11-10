#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

BASE_PACKAGES=(
    base-devel git curl wget rsync unzip
    greetd greetd-tuigreet
    flatpak firefox nemo gvfs gvfs-mtp tumbler file-roller
    hyprland quickshell waybar kitty
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    xdg-user-dirs xdg-utils wayland-protocols xorg-xwayland
    grim slurp wl-clipboard
    polkit-gnome libnotify
    pipewire pipewire-audio pipewire-pulse wireplumber
    networkmanager bluez bluez-utils
    mesa
)

# Update the system as a separate operation before installing extra packages.
# This avoids an unsafe partial-upgrade fallback if package sync/update fails.
sudo pacman -Syu --noconfirm

echo "Attempting the base package set..."
if sudo pacman -S --needed --noconfirm "${BASE_PACKAGES[@]}"; then
    echo "Base packages installed."
    exit 0
fi

echo "The grouped base-package operation failed. Retrying packages individually."
echo "Only packages that still fail will be skipped; the rest will be installed."
FAILED_PACKAGES=()
for package in "${BASE_PACKAGES[@]}"; do
    if sudo pacman -S --needed --noconfirm "$package"; then
        printf '[ OK ] %s\n' "$package"
    else
        printf '[SKIP] %s could not be installed.\n' "$package" >&2
        FAILED_PACKAGES+=("$package")
    fi
done

if ((${#FAILED_PACKAGES[@]} > 0)); then
    printf '\nBase packages skipped after individual retries:\n' >&2
    printf '  - %s\n' "${FAILED_PACKAGES[@]}" >&2
    exit 1
fi
