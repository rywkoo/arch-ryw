
-- autostart.lua
-- Hyprland 0.57+

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

-- Execute commands asynchronously and record their output.
local function run(label, command)
    local script = table.concat({
        'mkdir -p "$HOME/.local/state/hypr"',
        'printf "[%s] START %s\\n" "$(date)" '
            .. shell_quote(label)
            .. ' >> "$HOME/.local/state/hypr/autostart.log"',
        "{ " .. command
            .. '; } >> "$HOME/.local/state/hypr/autostart.log" 2>&1',
        "status=$?",
        'printf "[%s] EXIT %s status=%s\\n" "$(date)" '
            .. shell_quote(label)
            .. ' "$status" >> "$HOME/.local/state/hypr/autostart.log"',
    }, "; ")

    hl.exec_cmd("sh -c " .. shell_quote(script))
end

-- Confirms that this module was loaded.
run("autostart.lua loaded", "true")


------------------------------------------------
-- STARTUP: run once when Hyprland starts
------------------------------------------------

hl.on("hyprland.start", function()

    run("hyprland.start event", "true")

    -- Quickshell
    run("Quickshell",
        'qs -p "$HOME/.config/quickshell/shell.qml"')

    -- Notification daemon
    run("SwayNC", "swaync")

    -- Waybar
    run("Waybar", "waybar")

    -- Wallpaper daemon
    run("awww daemon", "awww-daemon")

    -- Wait for awww, then apply wallpaper
    run("Set wallpaper", [[
        i=0
        until awww query >/dev/null 2>&1; do
            i=$((i + 1))
            if [ "$i" -ge 50 ]; then
                echo "ERROR: awww daemon did not become ready" >&2
                exit 1
            fi
            sleep 0.1
        done

        awww img "$HOME/Pictures/wallpaper/hutao.jpg"
    ]])

    -- Polkit authentication agent
    run("Polkit",
        "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Remove unwanted applets after startup
    run("Remove applets",
        "sleep 10; killall -q nm-applet; killall -q blueman-applet")

    -- Remove stale Rofi PID file
    run("Remove stale Rofi PID",
        "rm -f /run/user/1000/rofi.pid")

    -- Applications
    run("Kitty", "kitty")
    run("Telegram", "Telegram")
    run("Discord", "discord")
    run("Steam", "steam")
    run("YouTube Music", "snap run youtube-music-desktop-app")

    -- Hyprland plugins
    run("Hyprland plugin reload", "hyprpm reload")
end)


------------------------------------------------
-- CONFIG RELOAD
------------------------------------------------

hl.on("config.reloaded", function()
    -- Restart SwayNC only if required
    hl.exec_cmd(
        "sh -c 'pkill -x swaync 2>/dev/null; swaync'"
    )
end)
