hl.config({
    input = {
        -- Focus follows the pointer. Focusing a window by keyboard or
        -- launcher warps the pointer to it instead.
        follow_mouse = 1,

        -- Closing the focused window focuses the one focused before it,
        -- which the stack then shows. The default asks the layout, and Lua
        -- layouts answer with the most recently opened window. 2 is "mru";
        -- the Lua config doesn't take the name.
        focus_on_close = 2,

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
