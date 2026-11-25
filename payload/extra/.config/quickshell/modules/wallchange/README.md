# Quickshell Wallchange

This is a QML-first replacement for the PyQt6 wallpaper manager and `rofiwall.sh`. It launches system utilities through Quickshell `Process` objects; there is no separate custom Python or Bash script.

## Install

```sh
mkdir -p ~/.config/quickshell/wallchange
cp shell.qml ~/.config/quickshell/wallchange/shell.qml
qs -c wallchange
```

This follows the same named-config layout as your existing `qs -c bar` setup.

## Dependencies

- Quickshell with `Quickshell.Io`
- `awww`
- `wal` / pywal
- ImageMagick (`convert`)
- `pkexec` and a working polkit authentication agent for the SDDM theme files
- `notify-send`, `pkill`, `pgrep`, `setsid`, `sed`, `cat`, `find`

## Paths retained

- `~/Pictures/wallpaper`
- `~/.config/rofi/image/background.jpg`
- `~/.config/hypr/appearance.conf`
- `~/.config/hypr/hyprlock.conf`
- `~/.config/hypr/hyprlock/image/image.jpg`
- `~/.config/cava/config`
- `~/.cache/wal/colors.json`
- `/usr/share/sddm/themes/RyW/`

## Before relying on it

Back up your existing Hyprland, Hyprlock, Cava and SDDM config files before testing. The privileged SDDM steps are optional in this version: if polkit is unavailable or authorization is declined, the user session can still update its own wallpaper and configuration files. Review the terminal output on the first run and verify that all desired SDDM keys exist in your theme's `theme.conf`.
