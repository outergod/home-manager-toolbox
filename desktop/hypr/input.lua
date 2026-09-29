hl.config({
    input = {
        -- Focus follows the pointer. Focusing a window by keyboard or
        -- launcher warps the pointer to it instead.
        follow_mouse = 1,

        -- US by default, Dvorak on Super+Tab (binds.lua).
        kb_layout  = "us,us",
        kb_variant = ",dvorak",
        kb_options = "compose:menu",

        -- Content follows the fingers, as on macOS.
        natural_scroll = true,
        touchpad = {
            natural_scroll = true,
        },
    },
})

-- The Kyria produces Dvorak in its firmware, so it stays on plain US and
-- the layout toggle can't reach it.
hl.device({
    name       = "splitkb.com-kyria-rev3",
    kb_layout  = "us",
    kb_variant = "",
})
