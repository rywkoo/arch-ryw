# Kinatsu QuickShell

A single Quickshell configuration with feature modules and shared Pywal styling.

## Structure

```text
quickshell/
├── shell.qml                 # Single ShellRoot composition / entry point
├── theme/
│   ├── Theme.qml             # Shared Pywal colors and font singleton
│   └── qmldir
├── modules/
│   ├── bar/                  # Bar and reusable bar elements
│   ├── launcher/             # Launcher UI and P3 components
│   ├── notifications/        # Notification center
│   ├── audio/                # PipeWire mixer
│   └── wallchange/           # Wallpaper drawer
└── scripts/
    └── main.sh               # Start and IPC command helper
```

The module folders contain their own `qmldir` declarations. `shell.qml` only composes them; feature-specific state and UI remain in their own components. The shared `theme/Theme.qml` is the palette source for bar, notifications, audio, and wallpaper drawer.

## Start

Install this folder at `~/.config/quickshell`, then run:

```sh
~/.config/quickshell/scripts/main.sh start
```

For Hyprland autostart, use this once:

```ini
exec-once = qs -p ~/.config/quickshell/shell.qml
```

Do not autostart the former individual named configs at the same time; this is now a combined shell.

## Trigger modules

```sh
~/.config/quickshell/scripts/main.sh launcher toggle
~/.config/quickshell/scripts/main.sh audio toggle
~/.config/quickshell/scripts/main.sh notifications toggle
~/.config/quickshell/scripts/main.sh wallchange toggle
```

Each accepts `toggle`, `open`, or `close`. These commands use `qs ipc call` and require the combined shell to be running.

Example Hyprland keybinds:

```ini
bind = SUPER, SPACE, exec, ~/.config/quickshell/scripts/main.sh launcher toggle
bind = SUPER, V, exec, ~/.config/quickshell/scripts/main.sh audio toggle
bind = SUPER, N, exec, ~/.config/quickshell/scripts/main.sh notifications toggle
bind = SUPER, W, exec, ~/.config/quickshell/scripts/main.sh wallchange toggle
```

Escape dismisses the focused overlay. The launcher exits search first, then closes on a second Escape; its close animation hides only the launcher and does not quit the whole shell.

## Notes

- Keep the launcher `background.mp4` in `modules/launcher/`.
- The launcher custom P3 font was not included in the supplied archive; its existing Sans fallback remains.
- The wallpaper drawer retains its existing system paths and apply workflow. Its 16-color swatches still read Pywal JSON, while actual panel colors come from the shared theme singleton.
- Back up the current `~/.config/quickshell` before replacing it and test the overlays in your Hyprland session.
