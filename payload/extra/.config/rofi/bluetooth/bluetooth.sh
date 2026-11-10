#!/bin/bash
theme="$HOME/.config/rofi/bluetooth/bluetooth.rasi"

notify() {
    notify-send "Bluetooth" "$1"
}

bt_on() {
    bluetoothctl show | grep -q "Powered: yes"
}

connected_device() {
    bluetoothctl devices Connected 2>/dev/null |
        sed 's/^Device [^ ]* //'
}

device_menu() {
    notify "Scanning for devices..."
    tmp=$(mktemp)

    # stdbuf forces line-buffered output so we actually receive lines
    # from bluetoothctl in real time instead of them sitting in a
    # fully-buffered pipe until the process exits.
    coproc BTCTL { stdbuf -oL -eL bluetoothctl; }

    # Make sure an agent is registered before we get anywhere near
    # pairing later on, otherwise pairing can silently hang.
    echo "agent on" >&"${BTCTL[1]}"
    echo "default-agent" >&"${BTCTL[1]}"
    sleep 0.3

    echo "scan on" >&"${BTCTL[1]}"

    end=$((SECONDS + 6))
    while ((SECONDS < end)); do
        if read -r -t 0.2 line <&"${BTCTL[0]}"; then
            echo "$line" >>"$tmp"
        fi
    done

    echo "scan off" >&"${BTCTL[1]}"
    echo "quit" >&"${BTCTL[1]}"
    wait "$BTCTL_PID" 2>/dev/null
    rm -f "$tmp"

    # Don't try to parse names out of the live scan event stream -
    # devices bluez already knows about only emit RSSI/TxPower CHG
    # lines, not a fresh [NEW] Device line with a name. Just ask
    # bluetoothctl for the resolved list after scanning, which
    # includes every cached name regardless of NEW vs CHG.
    devices=$(
        bluetoothctl devices |
        sed -E 's/^Device ([0-9A-F:]{17}) /\1|/' |
        awk -F'|' '{
            mac=$1
            name=$2
            if (length(name)==0) next
            print name "|" mac
        }'
    )

    [[ -z "$devices" ]] && {
        notify "No devices found"
        return
    }

    chosen=$(
        echo "$devices" |
        cut -d'|' -f1 |
        sort |
        rofi -dmenu \
            -p "Bluetooth Devices" \
            -theme "$theme"
    )
    [[ -z "$chosen" ]] && return

    addr=$(
        echo "$devices" |
        grep -F "$chosen|" |
        cut -d'|' -f2 |
        head -n1
    )
    [[ -z "$addr" ]] && {
        notify "Device not found"
        return
    }

    if ! bluetoothctl info "$addr" | grep -q "Paired: yes"; then
        if ! bluetoothctl pair "$addr"; then
            notify "Failed to pair with $chosen"
            return
        fi
    fi

    if bluetoothctl connect "$addr"; then
        notify "Connected to $chosen"
    else
        notify "Failed to connect to $chosen"
    fi
}

# Power handling
if ! bt_on; then
    choice=$(printf "󰂲 Enable Bluetooth\n" | rofi -dmenu -p "Bluetooth" -theme "$theme")
    [[ "$choice" == "󰂲 Enable Bluetooth" ]] || exit 0
    bluetoothctl power on
    notify "Bluetooth Enabled"
    exit 0
fi

connected=$(connected_device)
if [[ -n "$connected" ]]; then
    menu=$(printf "󰂱 Connected: %s\n󰂰 Connect Device\n󰂲 Disable Bluetooth\n" "$connected")
else
    menu=$(printf "󰂯 Bluetooth Enabled\n󰂰 Connect Device\n󰂲 Disable Bluetooth\n")
fi

choice=$(echo -e "$menu" | rofi -dmenu -p "Bluetooth" -theme "$theme")
case "$choice" in
    "󰂰 Connect Device")
        device_menu
        ;;
    "󰂲 Disable Bluetooth")
        bluetoothctl power off
        notify "Bluetooth Disabled"
        ;;
esac