-- Look (design.md D13): windows fill the monitor flush, below the bar, with
-- no gaps, borders or rounding.
hl.config({
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 0,
    },

    decoration = {
        rounding = 0,
        -- Without borders, slightly darker unfocused windows show which one
        -- has focus, e.g. in a split. Fullscreen windows are exempt
        -- (rules.lua).
        dim_inactive = true,
        dim_strength = 0.1,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },
})
