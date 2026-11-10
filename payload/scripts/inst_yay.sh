#!/usr/bin/env bash
set -Eeuo pipefail

STATE="${1:-$HOME/.local/state/ryw-installer}"
if command -v yay >/dev/null 2>&1; then
    echo "yay is already installed."
    exit 0
fi

command -v git >/dev/null 2>&1 || { echo "git is unavailable; skipping yay installation." >&2; exit 1; }
command -v makepkg >/dev/null 2>&1 || { echo "makepkg is unavailable; skipping yay installation." >&2; exit 1; }

YAY_BUILD="$STATE/build/yay"
mkdir -p "$(dirname "$YAY_BUILD")"
rm -rf "$YAY_BUILD"
git clone --depth 1 https://aur.archlinux.org/yay.git "$YAY_BUILD"
(
    cd "$YAY_BUILD"
    makepkg -si --noconfirm
)
command -v yay >/dev/null 2>&1 || { echo "yay installation could not be verified." >&2; exit 1; }
