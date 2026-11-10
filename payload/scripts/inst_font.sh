#!/usr/bin/env bash
set -Eeuo pipefail

sudo pacman -S --needed --noconfirm \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-dejavu \
    ttf-liberation \
    ttf-jetbrains-mono-nerd \
    ttf-firacode-nerd \
    otf-font-awesome

fc-cache -f
printf 'Font installation and font-cache refresh complete.\n'
