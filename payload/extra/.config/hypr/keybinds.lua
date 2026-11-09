-- keybinds.lua
-- Hyprland 0.57+ Lua keybindings

local mainMod = "SUPER"

local terminal = "kitty"
local fileManager = "xdg-open \"$HOME\""
local menu = "~/.config/rofi/launcher/launcher.sh"
local power = "~/.config/rofi/power/powermenu.sh"

------------------------------------------------
-- APPLICATIONS
------------------------------------------------

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))

------------------------------------------------
-- FOCUS
------------------------------------------------

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

------------------------------------------------
-- WORKSPACES
------------------------------------------------

for i = 1, 10 do
    local key = tostring(i % 10)

    -- Switch to workspace
    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i })
    )

    -- Move active window to workspace
    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i })
    )
end

------------------------------------------------
-- SCREENSHOTS / SYSTEM
------------------------------------------------

hl.bind(
    "SUPER + SHIFT + S",
    hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots")
)

hl.bind(
    "Print",
    hl.dsp.exec_cmd("grim ~/Pictures/Screenshot_$(date +%s).png")
)

hl.bind("ALT + F4", hl.dsp.exec_cmd(power))

hl.bind("SUPER + PERIOD", hl.dsp.exec_cmd("flatpak run it.mijorus.smile"))

------------------------------------------------
-- QUICKSHELL / CUSTOM SCRIPTS
------------------------------------------------

hl.bind(
    "SUPER + SHIFT + Q",
    hl.dsp.global("quickshell:wallchange-toggle")
)

hl.bind(
    "SUPER + backslash",
    hl.dsp.exec_cmd("~/.config/hypr/toggle-mode.sh")
)

------------------------------------------------
-- WAYBAR THEME SWITCHING
------------------------------------------------

hl.bind(
    "SUPER + SHIFT + bracketleft",
    hl.dsp.exec_cmd("~/.config/waybar/theme-switch.sh prev")
)

hl.bind(
    "SUPER + SHIFT + bracketright",
    hl.dsp.exec_cmd("~/.config/waybar/theme-switch.sh next")
)

------------------------------------------------
-- SPECIAL WORKSPACE / SCRATCHPAD
------------------------------------------------

hl.bind(
    mainMod .. " + I",
    hl.dsp.workspace.toggle_special("magic")
)

hl.bind(
    "SUPER + SHIFT + R",
    hl.dsp.window.move({ workspace = "special:magic" })
)

------------------------------------------------
-- WORKSPACE SCROLLING
------------------------------------------------

hl.bind(
    mainMod .. " + mouse_down",
    hl.dsp.focus({ workspace = "e+1" })
)

hl.bind(
    mainMod .. " + mouse_up",
    hl.dsp.focus({ workspace = "e-1" })
)

------------------------------------------------
-- WINDOW DRAG / RESIZE
------------------------------------------------

hl.bind(
    mainMod .. " + mouse:272",
    hl.dsp.window.drag(),
    { mouse = true }
)

hl.bind(
    mainMod .. " + mouse:273",
    hl.dsp.window.resize(),
    { mouse = true }
)

------------------------------------------------
-- AUDIO / BRIGHTNESS
------------------------------------------------

hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
    { locked = true, repeating = true }
)

hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
    { locked = true, repeating = true }
)

------------------------------------------------
-- MEDIA KEYS
------------------------------------------------

hl.bind(
    "XF86AudioNext",
    hl.dsp.exec_cmd("playerctl next"),
    { locked = true }
)

hl.bind(
    "XF86AudioPause",
    hl.dsp.exec_cmd("playerctl play-pause"),
    { locked = true }
)

hl.bind(
    "XF86AudioPlay",
    hl.dsp.exec_cmd("playerctl play-pause"),
    { locked = true }
)

hl.bind(
    "XF86AudioPrev",
    hl.dsp.exec_cmd("playerctl previous"),
    { locked = true }
)