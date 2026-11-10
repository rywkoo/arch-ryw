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
SCRIPTS="$BUNDLE_COPY/payload/scripts"
FAILED_STAGES=()

say() { printf '\n\033[1;36m[RYW]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[WARNING]\033[0m %s\n' "$*" >&2; }
die() { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# A failed stage is recorded, but does not terminate the main installation.
# Each stage is a separate process so its own `set -e` behavior remains reliable.
run_stage() {
    local description="$1"
    shift
    local status=0

    say "$description"
    if "$@"; then
        printf '\033[1;32m[ OK ]\033[0m %s\n' "$description"
    else
        status=$?
        warn "Stage failed with exit code $status: $description"
        warn "Skipping the remainder of this stage and continuing with the next stage."
        FAILED_STAGES+=("$description (exit $status)")
    fi
}

[[ -f /etc/arch-release ]] || die "This installer supports Arch Linux."
[[ "$EUID" -ne 0 ]] || die "Run this installer as your regular user, not with sudo."
command -v sudo >/dev/null 2>&1 || die "sudo is required."
command -v pacman >/dev/null 2>&1 || die "pacman was not found."
command -v cp >/dev/null 2>&1 || die "The standard cp utility is required."
[[ -d "$BUNDLE_DIR/payload/extra/.config/hypr" ]] || die "The archive is incomplete: the full Hyprland configuration is missing."
[[ -d "$BUNDLE_DIR/payload/scripts" ]] || die "The archive is incomplete: payload/scripts is missing."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_apps.sh" ]] || die "Missing package installation script."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_font.sh" ]] || die "Missing font installation script."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_shl.sh" ]] || die "Missing Zsh installation script."
[[ -f "$BUNDLE_DIR/payload/scripts/inst_pacman_config.sh" ]] || die "Missing pacman configuration script."
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

This installer installs your complete bundled configuration.
There is no setup wizard, temporary desktop, or Quickshell runtime dependency.

Fixed application defaults:
  Browser:       Firefox
  File manager:  Nemo
  Flatpak store: Bazaar

Recoverable errors are logged and skipped. Remaining installation stages continue.
Your existing configuration and shell files are backed up before replacement.
EOF

printf '\nInstallation log: %s\n' "$LOG_FILE"
read -r -p "Continue with the RyW installation? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { say "Cancelled. No installation changes were made."; exit 0; }

say "Requesting administrator authentication..."
sudo -v || die "Administrator authentication failed. Cannot continue safely."

# Keep a stable copy of the bundle without requiring rsync.
# If launched from the stable bundle itself, do not try to copy a directory into itself.
mkdir -p "$INSTALL_ROOT"
if [[ "$BUNDLE_DIR" != "$BUNDLE_COPY" ]]; then
    mkdir -p "$BUNDLE_COPY"
    cp -a "$BUNDLE_DIR/." "$BUNDLE_COPY/"
fi
[[ -d "$SCRIPTS" ]] || die "The installer payload could not be staged: $SCRIPTS is missing."

# Refresh sudo credentials during long-running operations.
( while true; do sudo -n true 2>/dev/null || exit; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
cleanup() { kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; }
trap cleanup EXIT

run_stage "Enabling Pacman Color and ILoveCandy download progress" \
    bash "$SCRIPTS/inst_pacman_config.sh" "$STAMP"

run_stage "Updating the system and installing base desktop packages" \
    bash "$SCRIPTS/inst_base.sh"

run_stage "Detecting and installing supported graphics drivers" \
    bash "$SCRIPTS/inst_gpu.sh"

run_stage "Configuring Flathub and installing Bazaar" \
    bash "$SCRIPTS/inst_flatpak_bazaar.sh"

run_stage "Installing Smile emoji picker" \
    bash "$SCRIPTS/inst_flatpak_smile.sh"

run_stage "Bootstrapping yay for AUR package support" \
    bash "$SCRIPTS/inst_yay.sh" "$STATE"

run_stage "Installing remaining official and AUR applications" \
    bash "$SCRIPTS/inst_apps.sh"

run_stage "Installing fonts and refreshing font cache" \
    bash "$SCRIPTS/inst_font.sh"

run_stage "Applying the complete bundled RyW configuration" \
    bash "$SCRIPTS/inst_wal.sh" "$BUNDLE_COPY/payload"

run_stage "Installing Oh My Zsh and configured Zsh plugins" \
    bash "$SCRIPTS/inst_shl.sh" "$SCRIPTS"

run_stage "Setting Firefox and Nemo as default applications" \
    bash "$SCRIPTS/inst_defaults.sh"

run_stage "Enabling NetworkManager and Bluetooth services" \
    bash "$SCRIPTS/inst_services.sh"

run_stage "Configuring greetd for automatic Hyprland startup" \
    bash "$SCRIPTS/inst_greetd.sh" "$STAMP"

run_stage "Checking installed packages and configuration files" \
    bash "$SCRIPTS/verify_install.sh"

printf '\n============================================================\n'
if ((${#FAILED_STAGES[@]} == 0)); then
    printf '\033[1;32mRyW installation completed. All stages reported success.\033[0m\n'
else
    printf '\033[1;33mRyW installation reached the end, but some stages were skipped.\033[0m\n'
    printf '\nStages that reported errors:\n'
    for failed in "${FAILED_STAGES[@]}"; do
        printf '  - %s\n' "$failed"
    done
    printf '\nReview the log and retry or fix only the failed stages.\n'
fi

cat <<EOF

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

The greetd login screen should appear after reboot.
Sign in with your normal user account; tuigreet launches Hyprland.

After login, check this session log if a component fails:
  ~/.local/state/hypr/autostart.log

A reboot is recommended after kernel or graphics driver changes.
============================================================
EOF

# Return a non-zero status when any stage failed so automation can detect
# an incomplete install, while still leaving the detailed summary and log.
((${#FAILED_STAGES[@]} == 0))
