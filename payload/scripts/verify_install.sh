#!/usr/bin/env bash
set -Eeuo pipefail

failures=0
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        printf '[ OK ] command: %s\n' "$1"
    else
        printf '[FAIL] command missing: %s\n' "$1"
        failures=$((failures + 1))
    fi
}
check_file() {
    if [[ -f "$1" ]]; then
        printf '[ OK ] file: %s\n' "$1"
    else
        printf '[FAIL] file missing: %s\n' "$1"
        failures=$((failures + 1))
    fi
}
check_dir() {
    if [[ -d "$1" ]]; then
        printf '[ OK ] directory: %s\n' "$1"
    else
        printf '[FAIL] directory missing: %s\n' "$1"
        failures=$((failures + 1))
    fi
}

echo "Checking required commands..."
for command_name in hyprland qs waybar kitty rofi swaync firefox nemo zsh flatpak yay tuigreet wal; do
    check_command "$command_name"
done

echo
echo "Checking the installed full configuration..."
check_file "$HOME/.config/hypr/hyprland.lua"
check_file "$HOME/.config/hypr/keybinds.lua"
check_file "$HOME/.config/hypr/autostart.lua"
check_file "$HOME/.config/waybar/config.jsonc"
check_file "$HOME/.config/waybar/style.css"
check_file "$HOME/.config/quickshell/shell.qml"
check_file "$HOME/.config/rofi/config.rasi"
check_file "$HOME/.config/zsh/.zshrc"
check_file "$HOME/.zshenv"
check_dir "$HOME/.config/quickshell/modules"
check_dir "$HOME/.config/waybar/Theme"

echo
echo "Checking Pacman download progress configuration..."
if grep -Eq '^[[:space:]]*Color([[:space:]]|$)' /etc/pacman.conf \
    && grep -Eq '^[[:space:]]*ILoveCandy([[:space:]]|$)' /etc/pacman.conf; then
    echo '[ OK ] Pacman Color and ILoveCandy enabled'
else
    echo '[FAIL] Pacman Color or ILoveCandy is not enabled'
    failures=$((failures + 1))
fi

echo
echo "Checking the current user's login shell..."
target_user="$(id -un)"
expected_zsh="$(command -v zsh || true)"
actual_shell="$(getent passwd "$target_user" | awk -F: '{print $7}')"
if [[ -n "$expected_zsh" && "$actual_shell" == "$expected_zsh" ]]; then
    printf '[ OK ] %s uses Zsh (%s)\n' "$target_user" "$actual_shell"
else
    printf '[FAIL] %s login shell is %s; expected %s\n' "$target_user" "${actual_shell:-unknown}" "${expected_zsh:-zsh not installed}"
    failures=$((failures + 1))
fi

echo
echo "Checking login manager configuration..."
if [[ -f /etc/greetd/config.toml ]] && grep -q 'tuigreet --time --cmd start-hyprland' /etc/greetd/config.toml; then
    echo '[ OK ] greetd launches Hyprland after login'
else
    echo '[FAIL] greetd configuration is missing or incorrect'
    failures=$((failures + 1))
fi
if systemctl is-enabled --quiet greetd.service; then
    echo '[ OK ] greetd service enabled'
else
    echo '[FAIL] greetd service is not enabled'
    failures=$((failures + 1))
fi

echo
echo "Checking fixed Flatpak applications..."
flatpak list --system --app --columns=application | grep -qx 'io.github.kolunmi.Bazaar' \
    && echo '[ OK ] Bazaar Flatpak' \
    || { echo '[FAIL] Bazaar Flatpak missing'; failures=$((failures + 1)); }
flatpak list --system --app --columns=application | grep -qx 'it.mijorus.smile' \
    && echo '[ OK ] Smile Flatpak' \
    || { echo '[FAIL] Smile Flatpak missing'; failures=$((failures + 1)); }

echo
if ((failures > 0)); then
    printf 'Verification found %d problem(s). Review the installer log and correct the listed items.\n' "$failures" >&2
    exit 1
fi
echo "All installation checks passed."
