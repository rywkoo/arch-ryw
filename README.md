# RyW Complete Installer

A one-entry installer for the supplied RyW Arch Linux + Hyprland dotfiles.

## Install

1. Extract this archive.
2. Open a terminal in the extracted `RyW-Complete-Installer` folder.
3. Run:

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

4. Confirm the installer. It installs the base Wayland/Hyprland stack, pulls `https://github.com/rywkoo/RyW-main`, and overlays the newer local dotfile snapshot included in this archive.
5. If the installer was run from a TTY, start the temporary session with `start-hyprland`. The Quickshell first-run wizard opens automatically. If run inside an existing Wayland session, it opens there.
6. Choose one browser, one file manager, and a Flatpak manager. The wizard opens Kitty to install those choices, install the remaining native dependencies/fonts/Zsh plugins, back up the temporary config, and apply the full RyW configuration.

## What it installs

- Hyprland, Quickshell, Waybar, Kitty, Hyprlock, Rofi, SwayNC, wallpaper and screenshot tooling.
- Wayland portals, PipeWire, NetworkManager, Bluetooth, polkit, and session utilities.
- Native developer/terminal utilities, Pywal, Qt6 multimedia support, UPower/udisks integration, and fonts.
- `yay` is bootstrapped automatically for later AUR use; the supplied dotfile set does not require AUR packages.
- Flatpak choices from the wizard: Firefox / Brave / Chromium; Dolphin; Bazaar. Bazaar is selected by default. Smile is installed because the existing Hyprland shortcut uses it.

## Important behavior

- SDDM is disabled and removed if installed. This bundle does not silently install or configure another display manager; start Hyprland from a TTY using `start-hyprland`.
- The installer backs up your existing `~/.config`, `.zshenv`, `.zprofile`, `.zshrc`, and `.p10k.zsh` before creating the temporary config. The final dotfile restore also backs up the temporary config before replacing it.
- The full final configuration is the `payload/extra/.config` snapshot supplied in the uploaded archive. That snapshot is intentionally overlaid on top of the current GitHub clone because it contains newer local Quickshell/Hyprland files than the public commit history.
- GUI apps with Flatpak choices are not duplicated in the pacman/AUR package lists. Browser/file-manager commands use `xdg-open` so they follow the selected defaults.
- Existing wallpaper files are not overwritten. Additional wallpapers are copied into `~/Pictures/wallpaper`.
- NVIDIA driver installation is conservative: Turing-and-newer NVIDIA GPUs are matched to `nvidia-open` / `nvidia-open-lts` for the detected standard kernel. Older GPUs and non-standard kernels are not changed automatically.

## Recovery

Backups and logs are stored in:

- `~/.local/state/ryw-installer/backups/`
- `~/.local/state/ryw-installer/logs/`

To restore the previous config, copy the desired backup's `.config` back to `~/.config`. The installer never deletes those backups.

## Testing note

The archive's shell scripts are syntax-checked and the ZIP integrity is verified before release. A live Hyprland/Quickshell session cannot be launched in this build environment, so display hardware, Qt/QML runtime behavior, and post-login services must still be verified on the target Arch machine.
