#!/usr/bin/env bash
set -Eeuo pipefail

failures=0
set_default() {
    local mime="$1"
    local desktop="$2"
    if ! xdg-mime default "$desktop" "$mime"; then
        printf 'Could not set %s as default for %s\n' "$desktop" "$mime" >&2
        failures=$((failures + 1))
    fi
}

if command -v xdg-mime >/dev/null 2>&1; then
    set_default x-scheme-handler/http firefox.desktop
    set_default x-scheme-handler/https firefox.desktop
    set_default inode/directory nemo.desktop
    set_default application/x-directory nemo.desktop
else
    echo "xdg-mime is unavailable. Skipping default application configuration." >&2
    exit 1
fi

if command -v xdg-settings >/dev/null 2>&1; then
    xdg-settings set default-web-browser firefox.desktop || {
        echo "xdg-settings could not set Firefox as the default browser." >&2
        failures=$((failures + 1))
    }
fi

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update || {
        echo "Could not refresh XDG user directories." >&2
        failures=$((failures + 1))
    }
fi

exit "$((failures > 0 ? 1 : 0))"
