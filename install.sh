#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

BUNDLE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALL_ROOT="$HOME/.local/share/ryw-installer"
BUNDLE_COPY="$INSTALL_ROOT/bundle"
STATE="$HOME/.local/state/ryw-installer"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$STATE/logs"
LOG_FILE="$LOG_DIR/install-$STAMP.log"
BACKUP_DIR="$STATE/backups/install-$STAMP"

say() { printf '\n\033[1;36m[RYW]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[WARNING]\033[0m %s\n' "$*" >&2; }
die() { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

on_error() {
    local status=$?
    printf '\n[ERROR] Installation stopped at line %s (exit %s).\n' "${BASH_LINENO[0]:-unknown}" "$status" >&2
    printf '[ERROR] Read the log: %s\n' "$LOG_FILE" >&2
    exit "$status"
}
trap on_error ERR

[[ -f /etc/arch-release ]] || die "This installer supports Arch Linux and Arch-based systems with pacman."
[[ "$EUID" -ne 0 ]] || die "Run this installer as your regular user. Do not run it with sudo."
command -v sudo >/dev/null 2>&1 || die "sudo is required."
command -v pacman >/dev/null 2>&1 || die "pacman was not found."
command -v rsync >/dev/null 2>&1 || die "rsync is required. Install it before continuing."
[[ -d "$BUNDLE_DIR/payload/extra/.config/hypr" ]] || die "The archive is incomplete: the full Hyprland configuration is missing."
[[ -d "$BUNDLE_DIR/payload/scripts" ]] || die "The archive is incomplete: payload/scripts is missing."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_apps.sh" ]] || die "Missing package installation script."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_font.sh" ]] || die "Missing font installation script."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_shl.sh" ]] || die "Missing Zsh installation script."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_wal.sh" ]] || die "Missing configuration installation script."

mkdir -p "$LOG_DIR" "$STATE/backups"
exec > >(tee -a "$LOG_FILE") 2>&1

cat <<'EOF'

  ____        __        __
 |  _ \ _   _\ \      / /
 | |_) | | | |\ \ /\ / /
 |  _ <| |_| | \ V  V /
 |_| \_\\__, |  \_/\_/
        |___/   COMPLETE INSTALLER

RyW Arch Linux + Hyprland installation

This installer uses your complete bundled configuration directly.
There is no setup wizard, temporary desktop, or Quickshell runtime step.

Fixed application defaults:
  Browser:       Firefox
  File manager:  Nemo
  Flatpak store: Bazaar

Your existing configuration and shell files will be backed up before replacement.
EOF

printf '\nInstallation log: %s\n' "$LOG_FILE"
read -r -p "Continue with the RyW installation? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { say "Cancelled. No installation changes were made."; exit 0; }

say "Requesting administrator authentication..."
sudo -v

# Keep a complete, stable copy of this bundle before running any child script.
say "Preparing the installer payload..."
mkdir -p "$INSTALL_ROOT"
mkdir -p "$BUNDLE_COPY"
rsync -a --delete --exclude='.git' --exclude='*.zip' "$BUNDLE_DIR/" "$BUNDLE_COPY/"
SCRIPTS="$BUNDLE_COPY/payload/scripts"

# Refresh sudo credentials while a long installation is running.
( while true; do sudo -n true 2>/dev/null || exit; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
cleanup() {
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

say "Updating package databases and installing the complete base desktop..."
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
sudo pacman -Syu --needed --noconfirm "${BASE_PACKAGES[@]}"

say "Detecting graphics hardware..."
GPU_INFO="$(lspci -nn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)"
if grep -Eqi 'NVIDIA' <<<"$GPU_INFO"; then
    if grep -Eqi 'RTX 20[0-9]{2}|RTX 30[0-9]{2}|RTX 40[0-9]{2}|RTX 50[0-9]{2}|GTX 16[0-9]{2}' <<<"$GPU_INFO"; then
        if pacman -Q linux >/dev/null 2>&1; then
            say "Installing NVIDIA open kernel modules for the standard linux kernel..."
            sudo pacman -S --needed --noconfirm nvidia-open nvidia-utils nvidia-prime egl-wayland linux-headers
        elif pacman -Q linux-lts >/dev/null 2>&1; then
            say "Installing NVIDIA open kernel modules for the linux-lts kernel..."
            sudo pacman -S --needed --noconfirm nvidia-open-lts nvidia-utils nvidia-prime egl-wayland linux-lts-headers
        else
            warn "NVIDIA hardware detected, but no standard linux/linux-lts kernel package was found. No mismatched driver will be installed."
            warn "Install the driver package and headers matching your custom kernel before starting Hyprland."
        fi
    else
        warn "NVIDIA hardware detected but the GPU generation was not positively matched to the open kernel module branch. Skipping automatic driver changes."
    fi
fi
if grep -Eqi 'Intel' <<<"$GPU_INFO"; then
    sudo pacman -S --needed --noconfirm vulkan-intel intel-media-driver
fi
if grep -Eqi 'AMD|Advanced Micro Devices' <<<"$GPU_INFO"; then
    sudo pacman -S --needed --noconfirm vulkan-radeon
fi

say "Configuring Flathub and installing the fixed Flatpak applications..."
sudo flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install --system --noninteractive --assumeyes flathub io.github.kolunmi.Bazaar
sudo flatpak install --system --noninteractive --assumeyes flathub it.mijorus.smile

say "Bootstrapping yay for AUR package support..."
if ! command -v yay >/dev/null 2>&1; then
    YAY_BUILD="$STATE/build/yay"
    mkdir -p "$(dirname "$YAY_BUILD")"
    rm -rf "$YAY_BUILD"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$YAY_BUILD"
    (
        cd "$YAY_BUILD"
        makepkg -si --noconfirm
    )
fi
command -v yay >/dev/null 2>&1 || die "yay bootstrap did not complete successfully."

say "Installing the remaining native and AUR packages..."
bash "$SCRIPTS/inst_apps.sh"

say "Installing fonts used by the supplied themes and interface..."
bash "$SCRIPTS/inst_font.sh"

say "Applying the complete bundled RyW configuration..."
bash "$SCRIPTS/inst_wal.sh" "$BUNDLE_COPY/payload"

say "Installing Oh My Zsh and the configured Zsh plugins..."
bash "$SCRIPTS/inst_shl.sh" "$SCRIPTS"

say "Setting fixed application defaults..."
xdg-mime default firefox.desktop x-scheme-handler/http
xdg-mime default firefox.desktop x-scheme-handler/https
xdg-mime default nemo.desktop inode/directory
xdg-mime default nemo.desktop application/x-directory
xdg-settings set default-web-browser firefox.desktop || warn "Could not set the default browser through xdg-settings; MIME defaults were still configured."
xdg-user-dirs-update || true

say "Enabling required system services..."
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service

say "Configuring automatic Hyprland session startup through greetd..."
# Keep a real login prompt: tuigreet authenticates the user before launching Hyprland.
# This avoids insecure passwordless autologin while removing the manual start-hyprland step.
sudo install -d -m 0755 /etc/greetd
if [[ -f /etc/greetd/config.toml ]]; then
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
    say "Disabling and removing SDDM to avoid competing display managers..."
    sudo systemctl disable --now sddm.service 2>/dev/null || true
    sudo pacman -Rns --noconfirm sddm
fi

sudo systemctl set-default graphical.target
sudo systemctl enable greetd.service

say "Running final installation checks..."
bash "$SCRIPTS/verify_install.sh"

cat <<EOF

============================================================
RyW installation completed.

Installed defaults:
  Firefox
  Nemo
  Bazaar (Flatpak)
  Smile (Flatpak)

Full configuration:
  $HOME/.config

Backups:
  $STATE/backups/

Installation log:
  $LOG_FILE

The installer does not launch a temporary desktop or start Quickshell.
The greetd login screen will appear automatically on the next boot.
Sign in with your normal user account; tuigreet will launch Hyprland.

After the first login, check the session log if any component fails:
  ~/.local/state/hypr/autostart.log

A reboot is recommended if the NVIDIA driver or kernel packages were changed.
============================================================
EOF
