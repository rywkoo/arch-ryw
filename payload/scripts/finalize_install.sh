#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

WALLPAPER="$HOME/Pictures/wallpaper/hutao.jpg"
CONFIG_DIR="$HOME/.config"
FAILURES=()
WARNINGS=()

ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; WARNINGS+=("$*"); }
fail() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; FAILURES+=("$*"); }

printf '\n============================================================\n'
printf 'RyW final desktop preparation\n'
printf '============================================================\n'

# Enable system services required independently of a graphical session.
for service in NetworkManager.service bluetooth.service greetd.service; do
    if sudo systemctl enable "$service"; then
        ok "Enabled $service"
    else
        fail "Could not enable $service"
    fi
done

# Start user audio services through their normal systemd user units.
if systemctl --user daemon-reload >/dev/null 2>&1; then
    if systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service; then
        ok 'PipeWire, PulseAudio compatibility and WirePlumber user services enabled'
    else
        warn 'Could not enable all PipeWire user units now; they will be checked again after login'
    fi
else
    warn 'No systemd user bus is available in this installer session; audio units will start on login through socket activation'
fi

# Refresh the font cache after all fonts and configuration files have been installed.
if command -v fc-cache >/dev/null 2>&1 && fc-cache -f; then
    ok 'Font cache refreshed'
else
    fail 'Font cache refresh failed'
fi

# The installer deploys this wallpaper from the bundled Hyprland wallpaper directory.
if [[ ! -f "$WALLPAPER" ]]; then
    mkdir -p "$(dirname "$WALLPAPER")"
    SOURCE_WALLPAPER="$CONFIG_DIR/hypr/wallpaper/hutao.jpg"
    if [[ -f "$SOURCE_WALLPAPER" ]]; then
        cp -n "$SOURCE_WALLPAPER" "$WALLPAPER"
    fi
fi

if [[ ! -s "$WALLPAPER" ]]; then
    fail "Required wallpaper is missing or empty: $WALLPAPER"
else
    ok "Wallpaper exists: $WALLPAPER"
fi

# Generate Pywal's color files before reboot. Awww applies the actual image in
# the active Wayland session; Hyprland autostart repeats both operations in order.
if [[ -s "$WALLPAPER" ]]; then
    if command -v wal >/dev/null 2>&1; then
        if wal -i "$WALLPAPER"; then
            ok 'Pywal palette generated from hutao.jpg'
        else
            fail 'Pywal could not generate the wallpaper palette'
        fi
    else
        fail 'The wal command is missing; Pywal cannot initialize the theme'
    fi
fi

# Awww needs a live Wayland compositor. If this installer was launched from
# Hyprland, initialize it now; otherwise Hyprland autostart applies the image
# at the first graphical login after reboot.
if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" ]] && command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
    if ! awww query >/dev/null 2>&1; then
        nohup awww-daemon >/dev/null 2>&1 </dev/null &
    fi

    ready=0
    for attempt in {1..50}; do
        if awww query >/dev/null 2>&1; then
            ready=1
            break
        fi
        sleep 0.1
    done

    if ((ready)); then
        if awww img "$WALLPAPER"; then
            ok 'Awww daemon is running and hutao.jpg has been applied'
        else
            fail 'Awww daemon started, but applying hutao.jpg failed'
        fi
    else
        fail 'Awww daemon did not become ready in the current Wayland session'
    fi
else
    warn 'No active Wayland session detected; Awww will start and apply hutao.jpg automatically at the first Hyprland login'
fi

# Ask Hyprland to parse and validate the deployed configuration without
# starting a compositor. This catches Lua/config errors before reboot.
if command -v hyprland >/dev/null 2>&1; then
    if hyprland --verify-config; then
        ok 'Hyprland configuration validation passed'
    else
        fail 'Hyprland configuration validation failed'
    fi
else
    fail 'Hyprland executable is missing; configuration cannot be validated'
fi

# hyprpm ships with Hyprland. It is a plugin manager, not a daemon or systemd
# service. This configuration currently has no plugin repository declarations.
if command -v hyprpm >/dev/null 2>&1; then
    if hyprpm --help >/dev/null 2>&1; then
        ok 'hyprpm is installed and its command starts successfully'
    else
        warn 'hyprpm exists but its help command returned an error'
    fi
else
    fail 'hyprpm is missing; reinstall or repair the Hyprland package'
fi

# Validate every bundled shell script before reboot.
while IFS= read -r -d '' script; do
    if bash -n "$script"; then
        ok "Shell syntax: ${script#"$CONFIG_DIR/"}"
    else
        fail "Shell syntax error: $script"
    fi
done < <(find "$CONFIG_DIR" -type f -name '*.sh' -print0)

printf '\nFinal preparation summary: %d failure(s), %d warning(s)\n' "${#FAILURES[@]}" "${#WARNINGS[@]}"
if ((${#FAILURES[@]})); then
    printf '\nItems requiring attention:\n'
    printf '  - %s\n' "${FAILURES[@]}"
fi
if ((${#WARNINGS[@]})); then
    printf '\nDeferred or non-fatal items:\n'
    printf '  - %s\n' "${WARNINGS[@]}"
fi

((${#FAILURES[@]} == 0))
