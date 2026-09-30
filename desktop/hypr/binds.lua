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

-- The front window of a workspace: the most recently focused tiled one.
local function front_window(workspace)
    local front
    for _, w in ipairs(hl.get_workspace_windows(workspace.id)) do
        if not w.floating and w.focus_history_id >= 0
            and (not front or w.focus_history_id < front.focus_history_id) then
            front = w
        end
    end
    return front
end

-- Swaps the front windows of the two monitors. Focus stays on the current
-- monitor, with the window that came over from the other one. Moving a
-- window focuses it, which also brings it to the front of its new stack.
local function swap_monitors()
    local here = hl.get_active_monitor()
    local there
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= here.name then there = m end
    end
    if not (there and here.active_workspace and there.active_workspace) then return end

    local mine = front_window(here.active_workspace)
    local theirs = front_window(there.active_workspace)
    if mine then
        hl.dispatch(hl.dsp.window.move({
            workspace = there.active_workspace.id, window = "address:" .. mine.address,
        }))
    end
    if theirs then
        hl.dispatch(hl.dsp.window.move({
            workspace = here.active_workspace.id, window = "address:" .. theirs.address,
        }))
        hl.dispatch(hl.dsp.focus({ window = "address:" .. theirs.address }))
    end
end

hl.bind("SUPER + Q", hl.dsp.window.close())

-- Every lock goes through logind, which has hypridle run hyprlock.
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))

-- The selected launcher (shell.nix): the omnibox on Ctrl+Space, which is
-- Cmd+Space on the Kyria in Mac mode, and its list of open windows on
-- Super+Space. Both only talk to the launcher's already running daemon.
if nix.launcher then
    hl.bind("CTRL + SPACE", hl.dsp.exec_cmd(nix.launcher))
end
if nix.windows then
    hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(nix.windows))
end

-- Temporary until the launcher exists.
hl.bind("SUPER + RETURN", app(nix.terminal))

-- Window model, see stack.lua.
hl.bind("SUPER + LEFT", hl.dsp.layout("left"))
hl.bind("SUPER + RIGHT", hl.dsp.layout("right"))
hl.bind("SUPER + UP", hl.dsp.layout("stack"))
hl.bind("SUPER + SHIFT + LEFT", move_to_monitor("left"))
hl.bind("SUPER + SHIFT + RIGHT", move_to_monitor("right"))
hl.bind("SUPER + DOWN", swap_monitors)
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("ALT + TAB", hl.dsp.focus({ last = true }))

-- Toggle US / Dvorak. There is no Lua dispatcher for it.
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("/usr/bin/hyprctl switchxkblayout all next"))

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
