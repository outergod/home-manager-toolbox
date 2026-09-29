local nix = require("nix")

-- Launch through uwsm so apps run as units in the session.
local function app(cmd)
    return hl.dsp.exec_cmd("uwsm app -- " .. cmd)
end

-- Moves the active window to the monitor on that side, where it keeps
-- focus and so comes to the front. There is one workspace per monitor, so
-- moving to the monitor means moving to its workspace.
local function move_to_monitor(side)
    return function()
        local w = hl.get_active_window()
        local from = w and w.monitor
        if not from then return end

        local to
        for _, m in ipairs(hl.get_monitors()) do
            local ahead = (side == "left" and m.x < from.x) or (side == "right" and m.x > from.x)
            if ahead and (not to or math.abs(m.x - from.x) < math.abs(to.x - from.x)) then
                to = m
            end
        end
        if not (to and to.active_workspace) then return end

        hl.dispatch(hl.dsp.window.move({ workspace = to.active_workspace.id }))
        hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
    end
end

hl.bind("SUPER + Q", hl.dsp.window.close())

-- Every lock goes through logind, which has hypridle run hyprlock.
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))

-- Temporary until the launcher exists.
hl.bind("SUPER + RETURN", app(nix.terminal))

-- Window model, see stack.lua.
hl.bind("SUPER + LEFT", hl.dsp.layout("left"))
hl.bind("SUPER + RIGHT", hl.dsp.layout("right"))
hl.bind("SUPER + UP", hl.dsp.layout("stack"))
hl.bind("SUPER + SHIFT + LEFT", move_to_monitor("left"))
hl.bind("SUPER + SHIFT + RIGHT", move_to_monitor("right"))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("ALT + TAB", hl.dsp.focus({ last = true }))

-- Floating windows.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media and volume keys, also on the lock screen.
local wpctl = "/usr/bin/wpctl"
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(wpctl .. " set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(wpctl .. " set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(nix.playerctl .. " play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(nix.playerctl .. " play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(nix.playerctl .. " next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(nix.playerctl .. " previous"), { locked = true })
