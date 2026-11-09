#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$HOME/.local/share/ryw-installer"
PAYLOAD="$ROOT/payload"
SCRIPTS="$PAYLOAD/scripts"
LOG_DIR="$HOME/.local/state/ryw-installer/logs"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

BROWSER_ID="${1:-org.mozilla.firefox}"
FILE_MANAGER_ID="${2:-org.kde.dolphin}"
MANAGER_ID="${3:-io.github.kolunmi.Bazaar}"
valid_flatpak_id() { [[ "$1" == "none" || "$1" =~ ^[A-Za-z0-9_]+([.-][A-Za-z0-9_]+)+$ ]]; }
for id in "$BROWSER_ID" "$FILE_MANAGER_ID" "$MANAGER_ID"; do
  valid_flatpak_id "$id" || { echo "Invalid Flatpak application ID: $id" >&2; exit 2; }
done

install_flatpak() {
  local id="$1"
  [[ "$id" == "none" ]] && return 0
  echo "Installing Flatpak: $id"
  flatpak install --user --assumeyes --noninteractive --or-update flathub "$id"
}

sudo -v
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
install_flatpak "$BROWSER_ID"
install_flatpak "$FILE_MANAGER_ID"
install_flatpak "$MANAGER_ID"
# Smile is used by the existing Super+Period keybinding.
flatpak install --user --assumeyes --noninteractive --or-update flathub it.mijorus.smile

# Finish package installation, fonts, shell plugins, and final dotfiles.
bash "$SCRIPTS/inst_apps.sh"
bash "$SCRIPTS/inst_font.sh"
bash "$SCRIPTS/inst_wal.sh"
bash "$SCRIPTS/inst_shl.sh" "$SCRIPTS"

# Assign default MIME handlers only for apps the user chose.
case "$BROWSER_ID" in
  org.mozilla.firefox) BROWSER_DESKTOP="org.mozilla.firefox.desktop" ;;
  com.brave.Browser) BROWSER_DESKTOP="com.brave.Browser.desktop" ;;
  org.chromium.Chromium) BROWSER_DESKTOP="org.chromium.Chromium.desktop" ;;
  *) BROWSER_DESKTOP="" ;;
esac
[[ -z "$BROWSER_DESKTOP" ]] || xdg-mime default "$BROWSER_DESKTOP" x-scheme-handler/http x-scheme-handler/https
case "$FILE_MANAGER_ID" in
  org.kde.dolphin) FM_DESKTOP="org.kde.dolphin.desktop" ;;
  *) FM_DESKTOP="" ;;
esac
[[ -z "$FM_DESKTOP" ]] || xdg-mime default "$FM_DESKTOP" inode/directory

# Start services required by the desktop session.
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service || true
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
xdg-user-dirs-update 2>/dev/null || true

# SDDM is deliberately removed; login is from a TTY with start-hyprland.
sudo systemctl disable --now sddm.service 2>/dev/null || true
if pacman -Q sddm >/dev/null 2>&1; then sudo pacman -Rns --noconfirm sddm || true; fi

# Refresh menu cache and reload current session when possible.
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  hyprctl reload || true
  pkill -x waybar 2>/dev/null || true
  waybar >/dev/null 2>&1 &
  pkill -x swaync 2>/dev/null || true
  swaync >/dev/null 2>&1 &
  pkill -f 'qs -p .*quickshell/shell.qml' 2>/dev/null || true
  qs -p "$HOME/.config/quickshell/shell.qml" >/dev/null 2>&1 &
fi

cat <<EOF

RyW setup completed.
- Full configuration is installed in ~/.config.
- Previous configuration backup: ~/.local/state/ryw-installer/backups/
- Setup log: $LOG
- SDDM has been removed; use start-hyprland from a TTY.
- Log out and back in for the Zsh login-shell change.

If this ran from a running Hyprland session, log out and start a fresh session
so all services and the full Quickshell setup are loaded cleanly.
EOF
read -r -p "Press Enter to close this Kitty window..." _ || true
