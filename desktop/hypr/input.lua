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

-- Keyboards that stay on plain US, out of the layout toggle's reach.
local us_only = {
    -- Their firmware decides the layout: the Kyria always produces
    -- Dvorak, the Preonic switches itself. The Preonic's letter keys
    -- come from drop-preonic. drop-preonic-keyboard is pinned too, in
    -- case they ever come from it.
    "splitkb.com-kyria-rev3",
    "drop-preonic",
    "drop-preonic-keyboard",
    -- Vicinae pastes and expands snippets through this uinput device, with
    -- keycodes that assume US.
    "vicinae-snippet-virtual-keyboard",
}
for _, name in ipairs(us_only) do
    hl.device({
        name       = name,
        kb_layout  = "us",
        kb_variant = "",
    })
end
