```bash
#!/bin/bash

theme="$HOME/.config/rofi/network/network.rasi"

notify() {
    notify-send "Network" "$1"
}

wifi_enabled() {
    [[ "$(nmcli radio wifi)" == "enabled" ]]
}

current_wifi() {
    nmcli -t -f ACTIVE,SSID dev wifi |
        awk -F: '$1=="yes"{print $2; exit}'
}

ethernet_connected() {
    nmcli -t -f TYPE,STATE dev |
        grep '^ethernet:connected$' >/dev/null
}

connect_menu() {
    ssid=$(
        nmcli -t -f SSID dev wifi list |
        sed '/^$/d' |
        sort -u |
        rofi -dmenu \
            -p "Available Networks" \
            -theme "$theme"
    )

    [[ -z "$ssid" ]] && exit 0

    # Already saved network
    if nmcli connection up "$ssid" >/dev/null 2>&1; then
        notify "Connected to $ssid"
        exit 0
    fi

    password=$(
        rofi -dmenu \
            -password \
            -p "Password for $ssid" \
            -theme "$theme"
    )

    [[ -z "$password" ]] && exit 1

    if nmcli dev wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
        notify "Connected to $ssid"
    else
        notify "Failed to connect to $ssid"
    fi
}

# Wi-Fi disabled
if ! wifi_enabled; then
    choice=$(
        printf "󰖩 Enable Wi-Fi\n" |
        rofi -dmenu \
            -p "Network" \
            -theme "$theme"
    )

    case "$choice" in
        "󰖩 Enable Wi-Fi")
            nmcli radio wifi on
            notify "Wi-Fi Enabled"
            ;;
    esac

    exit 0
fi

wifi_name=$(current_wifi)

if [[ -n "$wifi_name" ]]; then
    menu=$(
        printf "󰖩 Connected: %s\n󰒓 Switch Network\n󰖪 Disable Wi-Fi\n" "$wifi_name"
    )
elif ethernet_connected; then
    menu=$(
        printf "󰈀 Ethernet Connected\n󰖩 Connect to Wi-Fi\n󰖪 Disable Wi-Fi\n"
    )
else
    menu=$(
        printf "󰖩 Connect to Wi-Fi\n󰖪 Disable Wi-Fi\n"
    )
fi

choice=$(
    echo -e "$menu" |
    rofi -dmenu \
        -p "Network" \
        -theme "$theme"
)

case "$choice" in
    "󰖩 Connect to Wi-Fi")
        connect_menu
        ;;

    "󰒓 Switch Network")
        connect_menu
        ;;

    "󰈀 Ethernet Connected")
        :
        ;;

    "󰖩 Connected: $wifi_name")
        :
        ;;

    "󰖪 Disable Wi-Fi")
        nmcli radio wifi off
        notify "Wi-Fi Disabled"
        ;;
esac
```