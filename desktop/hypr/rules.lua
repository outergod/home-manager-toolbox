-- Keep the session awake while anything is fullscreen, e.g. a video.
-- Manual inhibition ("caffeine") comes from the shell.
hl.window_rule({
    name  = "idle-inhibit-fullscreen",
    match = { class = ".*" },

    idle_inhibit = "fullscreen",
})
