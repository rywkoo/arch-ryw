-- Kinatsu's Hyprland 0.57+ Lua autostart.
<<<<<<< HEAD
-- Keep this limited to session services; user applications are launched on demand.
=======
-- Initialize the wallpaper palette and Awww before launching color-dependent UI.
>>>>>>> 594005b (Improve installer finalization and desktop initialization)

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function run(label, command)
    local script = table.concat({
        'mkdir -p "$HOME/.local/state/hypr"',
        'printf "[%s] START %s\\n" "$(date)" ' .. shell_quote(label)
            .. ' >> "$HOME/.local/state/hypr/autostart.log"',
        "{ " .. command .. '; } >> "$HOME/.local/state/hypr/autostart.log" 2>&1',
        "status=$?",
        'printf "[%s] EXIT %s status=%s\\n" "$(date)" '
            .. shell_quote(label) .. ' "$status" >> "$HOME/.local/state/hypr/autostart.log"',
    }, "; ")
    hl.exec_cmd("sh -c " .. shell_quote(script))
end

run("autostart.lua loaded", "true")

hl.on("hyprland.start", function()
<<<<<<< HEAD
    run("Quickshell", 'qs -p "$HOME/.config/quickshell/shell.qml"')
    run("SwayNC", "swaync")
    run("Waybar", "waybar")
    run("awww daemon", "awww-daemon")
    run("Set wallpaper", [[
        i=0
        until awww query >/dev/null 2>&1; do
            i=$((i + 1))
            [ "$i" -lt 50 ] || { echo "awww daemon did not become ready" >&2; exit 1; }
            sleep 0.1
        done
        [ ! -f "$HOME/Pictures/wallpaper/hutao.jpg" ] || awww img "$HOME/Pictures/wallpaper/hutao.jpg"
    ]])
    run("Polkit agent", "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
=======
    -- Keep these operations in one shell so the order is deterministic.
    run("Desktop startup", [[
        wallpaper="$HOME/Pictures/wallpaper/hutao.jpg"

        if [ -s "$wallpaper" ]; then
            if command -v wal >/dev/null 2>&1; then
                wal -i "$wallpaper" || echo "Pywal palette generation failed" >&2
            else
                echo "wal command is missing" >&2
            fi
        else
            echo "Wallpaper is missing: $wallpaper" >&2
        fi

        if command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
            if ! awww query >/dev/null 2>&1; then
                nohup awww-daemon >/dev/null 2>&1 </dev/null &
            fi

            attempt=0
            until awww query >/dev/null 2>&1; do
                attempt=$((attempt + 1))
                [ "$attempt" -lt 50 ] || { echo "Awww daemon did not become ready" >&2; break; }
                sleep 0.1
            done

            if awww query >/dev/null 2>&1 && [ -s "$wallpaper" ]; then
                awww img "$wallpaper" || echo "Awww could not apply hutao.jpg" >&2
            fi
        else
            echo "Awww or awww-daemon is missing" >&2
        fi

        if command -v qs >/dev/null 2>&1; then
            qs -p "$HOME/.config/quickshell/shell.qml" &
        else
            echo "Quickshell command is missing" >&2
        fi

        if command -v swaync >/dev/null 2>&1; then swaync & else echo "SwayNC command is missing" >&2; fi
        if command -v waybar >/dev/null 2>&1; then waybar & else echo "Waybar command is missing" >&2; fi
        if [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
            /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
        else
            echo "Polkit authentication agent is missing" >&2
        fi
    ]])
>>>>>>> 594005b (Improve installer finalization and desktop initialization)
end)

hl.on("config.reloaded", function()
    hl.exec_cmd("sh -c 'pkill -x swaync 2>/dev/null; swaync'")
end)
