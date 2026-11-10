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
5. Allow the installer to complete. It records stage failures and continues with later stages.
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
2. Enable Pacman `Color` and `ILoveCandy` before the first package download
3. Full system update and base Hyprland/Wayland packages
4. GPU detection and supported graphics driver installation
5. Flathub setup and Bazaar installation
6. Smile installation
7. `yay` bootstrap
8. Remaining official and AUR packages
9. Fonts and font cache
10. Complete bundled `.config` deployment
11. Validate Zsh files, set the user's login shell to Zsh, then install Oh My Zsh/plugins
12. Default applications and user directories
13. NetworkManager and Bluetooth services
14. greetd/tuigreet login and automatic Hyprland session startup
15. Final file/package and login-shell verification

No temporary Hyprland configuration is installed. The wizard and all wizard startup logic have been removed. The installer does not launch Quickshell during installation.

## Error handling and recovery

Recoverable installation errors are logged. The failed stage is marked as skipped and the installer continues to later stages. Package-installation scripts retry grouped package installs one package at a time, so one unavailable package does not prevent the other packages in that list from being attempted.

Some errors are still fatal by design: running on a non-Arch system, running as root, missing `sudo`/`pacman`, an incomplete installer archive, or failing administrator authentication. The installer cannot safely proceed without these.

If any stage fails, the installer lists it at the end and returns a non-zero exit status to make the incomplete result visible. The full log is saved under `~/.local/state/ryw-installer/logs/`.

`rsync` is no longer a prerequisite. The installer copies its payload with the standard `cp` utility. `rsync` remains in the optional base package list, but if that package cannot be installed it will be skipped without blocking the configuration copy.

### Pywal and JACK compatibility

- The installer first tries the official `python-pywal` package. If that fails, it tries `python-pywal16` from the AUR and checks that the `wal` command is available. The supplied Quickshell wallpaper workflow uses `wal`.
- `pipewire-jack` is installed when no existing `jack2` or `jack2-dbus` package is detected. If JACK2 is already installed, the installer preserves that existing audio stack and intentionally skips `pipewire-jack` rather than removing JACK packages or breaking applications that depend on them. You can migrate the JACK implementation later after reviewing the packages that depend on JACK.

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


## Pacman appearance

Before the first package download, the installer backs up `/etc/pacman.conf`, enables `Color`, and adds `ILoveCandy`. This changes pacman's progress display from the default hash-style bar to the candy-style progress bar. The operation is idempotent and can safely be repeated.

## Zsh login shell

The installer validates the bundled Zsh startup files, registers the installed Zsh executable in `/etc/shells`, and uses `sudo chsh` (with a `usermod` fallback) to change the actual account shell. It verifies the account entry with `getent`. Oh My Zsh and plugin downloads happen after the account shell change, so network failures do not leave the account on Bash.

The new shell applies to future login sessions. Log out completely and log back in (or reboot) before checking `$SHELL`; an already-open terminal keeps running its existing shell process.
