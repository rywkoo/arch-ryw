#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/rywkoo/RyW-main.git"
BUNDLE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$HOME/.local/share/ryw-installer"
STATE="$HOME/.local/state/ryw-installer"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE/backups/bootstrap-$STAMP"

say() { printf '\n\033[1;36m[RYW]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f /etc/arch-release ]] || die "This installer targets Arch Linux."
[[ $EUID -ne 0 ]] || die "Run this installer as your regular user, not with sudo."
command -v sudo >/dev/null || die "sudo is required."
command -v pacman >/dev/null || die "pacman was not found."
[[ -d "$BUNDLE_DIR/payload/extra/.config" ]] || die "The archive is incomplete: payload/extra/.config is missing."

cat <<'EOF'

  ____        __        __
 |  _ \ _   _\ \      / /
 | |_) | | | |\ \ /\ / /
 |  _ <| |_| | \ V  V /
 |_| \_\\__, |  \_/\_/
        |___/   

This installs the Hyprland session and then opens a small first-run app wizard.
Existing ~/.config and shell files are backed up before they are replaced.
No SDDM, Steam, Discord, or Telegram packages are installed by this setup.
EOF
read -r -p "Continue with the RyW installation? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { say "Cancelled; no system changes made."; exit 0; }

sudo -v
mkdir -p "$INSTALL_ROOT" "$STATE/backups" "$BACKUP"

say "Installing core packages and the Wayland session..."
CORE_PACKAGES=(
  base-devel git curl rsync flatpak pciutils
  hyprland quickshell waybar kitty
  xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-user-dirs xdg-utils wayland-protocols xorg-xwayland
  grim slurp wl-clipboard polkit-gnome libnotify
  pipewire pipewire-audio pipewire-pulse wireplumber
  networkmanager bluez bluez-utils
)
sudo pacman -Syu --needed --noconfirm "${CORE_PACKAGES[@]}"

say "Detecting graphics hardware and selecting a safe NVIDIA package when applicable..."
if command -v lspci >/dev/null 2>&1; then
  GPU_INFO="$(lspci -nn 2>/dev/null | grep -Ei 'VGA compatible controller|3D controller|Display controller' || true)"
else
  GPU_INFO=""
fi
if grep -Eqi 'NVIDIA' <<<"$GPU_INFO"; then
  if grep -Eqi 'RTX 20[0-9]{2}|RTX 30[0-9]{2}|RTX 40[0-9]{2}|RTX 50[0-9]{2}|GTX 16[0-9]{2}' <<<"$GPU_INFO"; then
    if pacman -Q linux >/dev/null 2>&1; then
      sudo pacman -S --needed --noconfirm nvidia-open nvidia-utils nvidia-prime egl-wayland
    elif pacman -Q linux-lts >/dev/null 2>&1; then
      sudo pacman -S --needed --noconfirm nvidia-open-lts nvidia-utils nvidia-prime egl-wayland
    else
      say "NVIDIA Turing-or-newer GPU detected with a non-standard kernel. Install nvidia-open-dkms and matching headers for that kernel manually."
    fi
  else
    say "NVIDIA GPU detected, but it may be older than Turing. Skipping automatic driver installation to avoid installing an unsupported driver branch. Consult the ArchWiki NVIDIA driver table."
  fi
fi
if grep -Eqi 'Intel' <<<"$GPU_INFO"; then sudo pacman -S --needed --noconfirm mesa vulkan-intel intel-media-driver; fi
if grep -Eqi 'AMD|Advanced Micro Devices' <<<"$GPU_INFO"; then sudo pacman -S --needed --noconfirm mesa vulkan-radeon; fi

say "Pulling the GitHub repository, then overlaying this archive's newer working snapshot..."
SOURCE="$INSTALL_ROOT/source"
if [[ -d "$SOURCE/.git" ]]; then
  git -C "$SOURCE" pull --ff-only || say "GitHub update failed; continuing with the bundled snapshot."
else
  rm -rf "$SOURCE"
  if ! git clone --depth 1 "$REPO_URL" "$SOURCE"; then
    mkdir -p "$SOURCE"
    say "Git clone failed; bundled files are still available and will be used."
  fi
fi
# Snapshot intentionally supersedes older committed copies of the same files.
# Replace only the repository's tracked working-tree directories; preserve its .git metadata and root files.
rm -rf "$SOURCE/extra" "$SOURCE/scripts"
ln -s ../payload/extra "$SOURCE/extra"
ln -s ../payload/scripts "$SOURCE/scripts"
# Keep the exact installer bundle in a stable location for the wizard and logs.
rsync -a --exclude='.git' --exclude='*.zip' "$BUNDLE_DIR/" "$INSTALL_ROOT/"

say "Bootstrapping yay for future AUR use..."
if ! command -v yay >/dev/null 2>&1; then
  YAY_BUILD="$STATE/yay-build"
  rm -rf "$YAY_BUILD"
  if git clone --depth 1 https://aur.archlinux.org/yay.git "$YAY_BUILD"; then
    (cd "$YAY_BUILD" && makepkg -si --noconfirm) || say "yay build failed; no AUR packages are needed for the included configuration."
  else
    say "Could not clone yay. The bundled setup has no required AUR packages; continue without it."
  fi
fi

say "Backing up existing configuration before creating a temporary desktop..."
for item in .config .zshenv .zprofile .zshrc .p10k.zsh; do
  if [[ -e "$HOME/$item" ]]; then
    cp -a "$HOME/$item" "$BACKUP/"
  fi
done
mkdir -p "$HOME/.config"
# Temporary config is deliberately small; the full dotfiles replace it after app selection.
rsync -a --delete "$INSTALL_ROOT/installer/bootstrap/.config/" "$HOME/.config/"
cat > "$HOME/.zshenv" <<'EOF'
export ZDOTDIR="$HOME/.config/zsh"
EOF
mkdir -p "$HOME/Pictures/wallpaper" "$HOME/Pictures/Screenshots" "$HOME/.local/state/ryw-installer"

say "Enabling basic network and Bluetooth services..."
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service || true

say "Bootstrap is ready. Starting the first-run wizard..."
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  qs -p "$INSTALL_ROOT/installer/bootstrap/setup-wizard.qml" >/dev/null 2>&1 &
elif [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  qs -p "$INSTALL_ROOT/installer/bootstrap/setup-wizard.qml" >/dev/null 2>&1 &
else
  echo
  echo "Bootstrap installed. Start the temporary Hyprland session from a TTY with:"
  echo "  start-hyprland"
  echo "The wizard opens automatically after Hyprland starts."
fi

cat <<EOF

RyW bootstrap completed.
Backup created at: $BACKUP
Repository: $REPO_URL
Bundled snapshot: $INSTALL_ROOT/payload

The final app/config step runs in Kitty from the Quickshell wizard.
EOF
