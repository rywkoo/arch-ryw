# RyW Complete Installer

A single-entry Arch Linux installer for the complete RyW Hyprland configuration.

## Installation

1. Extract the archive.
2. Open a terminal in the `RyW-Complete-Installer` directory.
3. Run:

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

4. Read the preflight summary and confirm the installation.
5. Allow the installer to complete. Do not close the terminal while it is running.
6. When it finishes, reboot. The greetd/tuigreet login screen will appear automatically; sign in with your normal user account and Hyprland will start.

A reboot is recommended after installation, especially if NVIDIA driver or kernel packages were changed.

## Fixed application defaults

There is no application picker or setup wizard.

- Browser: Firefox (native Arch package)
- File manager: Nemo (native Arch package)
- Flatpak manager: Bazaar (Flathub system installation)
- Emoji picker: Smile (Flathub system installation)

The installer configures Firefox and Nemo as the default handlers.

## Installation sequence

The top-level `install.sh` runs the full setup in one ordered process:

1. Preflight checks, logging, and a stable copy of the bundle
2. System update and base Hyprland/Wayland packages
3. GPU detection and supported graphics driver installation
4. Flathub setup and fixed Flatpak applications
5. Remaining official and AUR packages
6. Fonts and font cache
7. `yay` bootstrap
8. Complete bundled `.config` deployment
9. Oh My Zsh and configured plugins
10. Default applications and user directories
11. NetworkManager and Bluetooth services
12. greetd/tuigreet login and automatic Hyprland session startup
13. Final file/package verification

No temporary Hyprland configuration is installed. The wizard and all wizard startup logic have been removed. The installer does not launch Quickshell during installation.

## Configuration fidelity

The installer copies the complete `payload/extra/.config` directory into `~/.config`. This includes the supplied Hyprland Lua configuration and keybindings, Waybar themes and scripts, Quickshell modules, Rofi configuration, Kitty settings, Zsh configuration, and other bundled application settings.

The installer does not generate substitute keybindings or a simplified desktop configuration.

## Backups and logs

- Configuration backups: `~/.local/state/ryw-installer/backups/`
- Installer logs: `~/.local/state/ryw-installer/logs/`
- Stable installer payload: `~/.local/share/ryw-installer/bundle/`

The existing `~/.config`, `.zshenv`, and `.p10k.zsh` are backed up before replacement. Existing wallpaper files are not overwritten.

## Login and automatic session startup

SDDM is disabled and removed if installed. The installer installs and configures greetd with tuigreet. After reboot, a terminal login screen appears automatically; authenticate with your normal user account and tuigreet starts `start-hyprland` for you. This is not passwordless autologin: your account remains protected by its normal password.

## Important notes

- Run as your regular user, not with `sudo`.
- An internet connection is required for packages, Flathub, AUR, and Zsh plugins.
- `awww` and `hyprshot` are installed from the AUR through `yay`.
- NVIDIA driver installation is limited to detected Turing-or-newer GPUs using a standard Arch `linux` or `linux-lts` kernel. Custom kernels require their matching driver and headers.
- Final checks verify required commands and configuration files. They cannot emulate a real graphical Hyprland/Quickshell session, so session-specific hardware behavior must be checked after login.
