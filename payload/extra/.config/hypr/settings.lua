-- Appearance and layout settings converted from appearance.conf.
hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 5,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(004ac1ee)", "rgba(0246ffee)" }, angle = 45 },
            inactive_border = { colors = { "rgba(8c47feaa)", "rgba(0067f3aa)" }, angle = 45 },
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 20,
        rounding_power = 2,
        active_opacity = 0.8,
        inactive_opacity = 0.7,
        fullscreen_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = true,
            size = 5,
            passes = 5,
            vibrancy = 0.8,
	    new_optimizations = true,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})
-- Original layer effect: blur rofi and ignore alpha.
hl.layer_rule({
    name = "rofi-blur",
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 1,
})
