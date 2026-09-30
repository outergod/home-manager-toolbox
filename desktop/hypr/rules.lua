-- Keep the session awake while anything is fullscreen, e.g. a video.
-- Manual inhibition ("caffeine") comes from the shell.
hl.window_rule({
    name  = "idle-inhibit-fullscreen",
    match = { class = ".*" },

    idle_inhibit = "fullscreen",
})

-- A fullscreen video on the other monitor stays bright (look.lua dims
-- unfocused windows).
hl.window_rule({
    name  = "no-dim-fullscreen",
    match = { fullscreen = true },

    no_dim = true,
})

-- Synology Drive's tray popup closes when it loses focus, which with focus
-- following the pointer happens on the first mouse move.
hl.window_rule({
    name  = "synology-popup-stay-focused",
    match = { title = "^cloud-drive-ui$" },

    stay_focused = true,
})

-- Tiled windows already fill the monitor.
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Dialogs float centred at their own size. Hyprland floats transient
-- windows itself; these cover the rest.
local function dialog_rule(name, match)
    hl.window_rule({
        name  = name,
        match = match,

        float          = true,
        center         = true,
        suppress_event = "maximize fullscreen",
    })
end

dialog_rule("float-modal", { modal = true })

-- Portal file pickers, polkit and pinentry.
dialog_rule("float-prompts", {
    class = "^(xdg-desktop-portal-.*|org\\.freedesktop\\.impl\\.portal\\..*|hyprpolkitagent|gcr-prompter|pinentry-.*)$",
})
