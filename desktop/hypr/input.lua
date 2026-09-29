hl.config({
    input = {
        -- Focus follows the pointer. Focusing a window by keyboard or
        -- launcher warps the pointer to it instead.
        follow_mouse = 1,

        -- Content follows the fingers, as on macOS.
        natural_scroll = true,
        touchpad = {
            natural_scroll = true,
        },
    },
})
