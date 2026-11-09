-- Converted rules from windowrules.conf; matching is based on the original class/title.
hl.window_rule({
    name = "kitty-float-fix", match = { class = "^(kitty)$" },
    float = true, size = "900 600", center = true, suppress_event = "fullscreen maximize",
})
hl.window_rule({ name = "pavucontrol-float", match = { class = "org.pulseaudio.pavucontrol" }, float = true })
hl.window_rule({ name = "pavucontrol-size", match = { class = "org.pulseaudio.pavucontrol" }, size = "1000 800" })
hl.window_rule({ name = "pavucontrol-center", match = { class = "org.pulseaudio.pavucontrol" }, center = true })

hl.window_rule({ name = "cava-float", match = { title = "cava" }, float = true })
hl.window_rule({ name = "cava-move", match = { title = "cava" }, move = "100 800" })
hl.window_rule({ name = "cava-size", match = { title = "cava" }, size = "1040 200" })

hl.window_rule({ name = "gotop-float", match = { title = "gotop" }, float = true })
hl.window_rule({ name = "gotop-move", match = { title = "gotop" }, move = "1150 64" })
hl.window_rule({ name = "gotop-size", match = { title = "gotop" }, size = "600 600" })

hl.window_rule({ name = "cmatrix-float", match = { title = "cmatrix" }, float = true })
hl.window_rule({ name = "cmatrix-size", match = { title = "cmatrix" }, size = "600 327" })
hl.window_rule({ name = "cmatrix-move", match = { title = "cmatrix" }, move = "1150 673" })

hl.window_rule({ name = "wallchanger-float", match = { title = "WallChanger" }, float = true })
hl.window_rule({ name = "wallchanger-size", match = { title = "WallChanger" }, size = "300 100" })

hl.window_rule({ name = "wallpaper-manager-float", match = { title = "Wallpaper Manager" }, float = true })
hl.window_rule({ name = "wallpaper-manager-size", match = { title = "Wallpaper Manager" }, size = "1000 900" })
hl.window_rule({ name = "wallpaper-manager-center", match = { title = "Wallpaper Manager" }, center = true })

hl.window_rule({ name = "xwayland-fix", match = { xwayland = true } })
hl.window_rule({ name = "easyeffects-ws6", match = { class = "com.github.wwmm.easyeffects" }, workspace = 6 })
hl.window_rule({ name = "qpwgraph-ws6", match = { class = "org.rncbc.qpwgraph" }, workspace = 6 })
