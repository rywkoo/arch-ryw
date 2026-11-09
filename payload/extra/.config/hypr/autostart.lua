-- Kinatsu's Hyprland 0.57+ Lua autostart.
-- Keep this limited to session services; user applications are launched on demand.

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
end)

hl.on("config.reloaded", function()
    hl.exec_cmd("sh -c 'pkill -x swaync 2>/dev/null; swaync'")
end)
