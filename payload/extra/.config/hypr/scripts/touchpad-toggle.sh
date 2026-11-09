#!/usr/bin/env bash

STATE_FILE="$HOME/.config/hypr/scripts/.touchpad_state"

# Device names from libinput list-devices
TOUCHPAD1="MSNB0001:00 04F3:30AA Touchpad"
TOUCHPAD2="ETPS/2 Elantech Touchpad"

# Check state file
if [[ -f "$STATE_FILE" && $(cat "$STATE_FILE") == "off" ]]; then
    echo "on" > "$STATE_FILE"
    hyprctl notify 1 3000 "󰍹 Enabling touchpad"
    sudo udevadm control --reload-rules
    sudo udevadm trigger
else
    echo "off" > "$STATE_FILE"
    hyprctl notify 1 3000 "󰜉 Disabling touchpad"

    # Temporarily apply udev rule
    echo 'ACTION=="add|change", ATTRS{name}=="'"$TOUCHPAD1"'", ENV{LIBINPUT_IGNORE_DEVICE}="1"' | sudo tee /etc/udev/rules.d/99-touchpad-disable.rules
    echo 'ACTION=="add|change", ATTRS{name}=="'"$TOUCHPAD2"'", ENV{LIBINPUT_IGNORE_DEVICE}="1"' | sudo tee -a /etc/udev/rules.d/99-touchpad-disable.rules

    sudo udevadm control --reload-rules
    sudo udevadm trigger
fi

