#!/usr/bin/env bash
set -Eeuo pipefail

STAMP="${1:-$(date +%Y%m%d-%H%M%S)}"

command -v tuigreet >/dev/null 2>&1 || {
    echo "tuigreet is not installed. Skipping automatic login manager setup." >&2
    exit 1
}
id greeter >/dev/null 2>&1 || {
    echo "The greetd greeter account is missing. Skipping greetd setup." >&2
    exit 1
}

sudo install -d -m 0755 /etc/greetd
if sudo test -f /etc/greetd/config.toml; then
    sudo cp -a /etc/greetd/config.toml "/etc/greetd/config.toml.ryw-backup-$STAMP"
fi
sudo tee /etc/greetd/config.toml >/dev/null <<'GREETD_CONFIG'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --cmd start-hyprland"
user = "greeter"
GREETD_CONFIG

if pacman -Q sddm >/dev/null 2>&1; then
    sudo systemctl disable --now sddm.service || true
    sudo pacman -Rns --noconfirm sddm
fi

sudo systemctl set-default graphical.target
sudo systemctl enable greetd.service
