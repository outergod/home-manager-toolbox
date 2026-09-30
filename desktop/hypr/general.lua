hl.config({
    misc = {
        -- Lets a restarted hyprlock take over after a crash.
        allow_session_lock_restore = true,
        force_default_wallpaper    = 0,
    },

    -- X11 apps get real pixels instead of a blurry upscale at scale 2, but
    -- render at scale 1 unless they scale themselves (Steam: session.nix).
    xwayland = {
        force_zero_scaling = true,
    },
})
