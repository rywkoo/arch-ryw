#!/bin/bash

STATE="$HOME/.cache/hypr_mode"

mkdir -p "$(dirname "$STATE")"

if [[ ! -f "$STATE" ]]; then
    echo "home" > "$STATE"
fi

MODE=$(cat "$STATE")

if [[ "$MODE" == "home" ]]; then
    ############################
    # Switch to GAME MODE
    ############################

    hyprctl keyword general:gaps_in 0
    hyprctl keyword general:gaps_out 0
    hyprctl keyword general:border_size 0
    hyprctl keyword decoration:rounding 0
    hyprctl keyword decoration:blur:enabled false
    hyprctl keyword decoration:shadow:enabled false
    hyprctl keyword animations:enabled false

    # Optional
    pkill hypridle 2>/dev/null

    # Pause notifications (dunst)
    pkill -SIGUSR1 dunst 2>/dev/null

    notify-send "Hyprland" "Game Mode Enabled"

    echo "game" > "$STATE"

else
    ############################
    # Switch to HOME MODE
    ############################

    hyprctl keyword general:gaps_in 5
    hyprctl keyword general:gaps_out 5
    hyprctl keyword general:border_size 2
    hyprctl keyword decoration:rounding 20
    hyprctl keyword decoration:blur:enabled true
    hyprctl keyword decoration:shadow:enabled true
    hyprctl keyword animations:enabled true

    # Restart hypridle
    pgrep hypridle >/dev/null || hypridle &

    # Resume notifications
    pkill -SIGUSR2 dunst 2>/dev/null

    notify-send "Hyprland" "Home Mode Enabled"

    echo "home" > "$STATE"

fi