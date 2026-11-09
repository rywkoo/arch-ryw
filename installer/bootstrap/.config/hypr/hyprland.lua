-- Temporary bootstrap config. It is replaced by the full RyW config after setup.
hl.config({
  general = { gaps_in = 4, gaps_out = 8, border_size = 2, layout = "dwindle" },
  decoration = { rounding = 10, blur = { enabled = false } },
  misc = { disable_hyprland_logo = true },
})
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + M", hl.dsp.exit())
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("qs -p \"$HOME/.local/share/ryw-installer/installer/bootstrap/setup-wizard.qml\"")
end)
