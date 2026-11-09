
#!/usr/bin/env bash

set -euo pipefail

WAYBAR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$WAYBAR_DIR/Theme"
STATE_FILE="$WAYBAR_DIR/.current-theme"
DIRECTION="${1:-next}"

if [[ "$DIRECTION" != "next" && "$DIRECTION" != "prev" ]]; then
    echo "Usage: $0 [next|prev]"
    exit 1
fi

# Find theme folders containing both required files.
mapfile -t THEMES < <(
    find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d -print |
        sort |
        while IFS= read -r dir; do
            if [[ -f "$dir/config.jsonc" && -f "$dir/style.css" ]]; then
                printf '%s\n' "$dir"
            fi
        done
)

if (( ${#THEMES[@]} == 0 )); then
    echo "Error: No valid themes found in $THEME_DIR"
    exit 1
fi

# Read saved theme.
CURRENT=""
if [[ -f "$STATE_FILE" ]]; then
    CURRENT="$(<"$STATE_FILE")"
fi

# Validate saved theme.
INDEX=-1
for i in "${!THEMES[@]}"; do
    if [[ "${THEMES[$i]}" == "$CURRENT" ]]; then
        INDEX=$i
        break
    fi
done

# If no valid saved theme exists, detect the active theme.
if (( INDEX == -1 )); then
    for i in "${!THEMES[@]}"; do
        if cmp -s "$WAYBAR_DIR/config.jsonc" \
            "${THEMES[$i]}/config.jsonc" &&
           [[ -f "$WAYBAR_DIR/style.css" ]] &&
           diff -q \
            <(tail -n +2 "$WAYBAR_DIR/style.css") \
            <(tail -n +2 "${THEMES[$i]}/style.css") \
            >/dev/null 2>&1; then
            INDEX=$i
            break
        fi
    done
fi

# Select next or previous theme.
COUNT=${#THEMES[@]}

if [[ "$DIRECTION" == "next" ]]; then
    INDEX=$(( (INDEX + 1) % COUNT ))
else
    if (( INDEX == -1 )); then
        INDEX=0
    fi
    INDEX=$(( (INDEX - 1 + COUNT) % COUNT ))
fi

NEW_THEME="${THEMES[$INDEX]}"
THEME_NAME="$(basename -- "$NEW_THEME")"

# Copy the configuration.
cp -- "$NEW_THEME/config.jsonc" "$WAYBAR_DIR/config.jsonc"

# Use the selected theme's CSS, but always use your wal.css import.
TEMP_CSS="$(mktemp "$WAYBAR_DIR/.style.css.XXXXXX")"
trap 'rm -f -- "$TEMP_CSS"' EXIT

printf '@import "wal.css";\n' > "$TEMP_CSS"
tail -n +2 "$NEW_THEME/style.css" >> "$TEMP_CSS"
mv -- "$TEMP_CSS" "$WAYBAR_DIR/style.css"

# Save the selected theme.
printf '%s\n' "$NEW_THEME" > "$STATE_FILE"

# Restart Waybar.
pkill -x waybar 2>/dev/null || true
sleep 0.3
nohup waybar >/dev/null 2>&1 </dev/null &

# Reload Hyprland.
hyprctl reload

# Notify.
if command -v notify-send >/dev/null 2>&1; then
    notify-send "Waybar Theme" "Switched to: $THEME_NAME"
else
    echo "Switched to Waybar theme: $THEME_NAME"
fi
