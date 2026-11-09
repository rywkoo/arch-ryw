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
- `notify-send`, `pkill`, `pgrep`, `setsid`, `sed`, `cat`, `find`

## Paths retained

- `~/Pictures/wallpaper`
- `~/.config/rofi/image/background.jpg`
- `~/.config/hypr/appearance.conf`
- `~/.config/hypr/hyprlock.conf`
- `~/.config/hypr/hyprlock/image/image.jpg`
- `~/.config/cava/config`
- `~/.cache/wal/colors.json`

## Before relying on it

Back up your existing Hyprland, Hyprlock, and Cava config files before testing. This module only updates files in your home directory; it does not change or require a display-manager theme.
