-- The window model (design.md D5): one workspace per monitor, each a stack
-- of windows filling the monitor with the most recently focused in front.
-- The layout messages "left" and "right" split the monitor in halves with
-- the previously focused window, "stack" goes back.
--
-- Only the front window (or the split pair) is on screen. The others are
-- parked below all monitors: Hyprland finds the tiled window under the
-- pointer regardless of z-order, so overlapping windows would steal hover
-- focus and clicks from the front one.

local monitors = require("monitors")

-- Far below any monitor, so parked windows are neither drawn nor hit.
local PARK_Y = 100000

-- Split state per workspace ID: { left = stable_id, right = stable_id }.
-- Stable IDs, unlike addresses, are never reused.
local splits = {}

-- ctx has no workspace, but each workspace has its own layout instance.
local function workspace_of(ctx)
    for _, t in ipairs(ctx.targets) do
        if t.window and t.window.workspace then
            return t.window.workspace
        end
    end
end

-- The most recently focused window. One that never had focus yet (history
-- ID -1) just opened, and goes in front too.
local function front_of(ctx)
    local front
    for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w then
            local rank = w.focus_history_id < 0 and -1 or w.focus_history_id
            if not front or rank <= front.rank then
                front = { id = w.stable_id, rank = rank }
            end
        end
    end
    return front and front.id
end

local function halves(area)
    local w = math.floor(area.w / 2)
    return { x = area.x, y = area.y, w = w, h = area.h },
        { x = area.x + w, y = area.y, w = area.w - w, h = area.h }
end

-- Hyprland insets box edges that don't touch the monitor's area by
-- gaps_in. Growing the parked box by that keeps the window's size, so apps
-- don't re-layout on every focus change.
local function parked(box)
    local gaps = hl.get_config("general.gaps_in")
    local top, bottom = gaps.top or 0, gaps.bottom or 0
    return { x = box.x, y = box.y + PARK_Y - top, w = box.w, h = box.h + top + bottom }
end

local function recalculate(ctx)
    local ws = workspace_of(ctx)
    if not ws then
        for _, t in ipairs(ctx.targets) do t:place(ctx.area) end
        return
    end
    local split = splits[ws.id]

    local present = {}
    for _, t in ipairs(ctx.targets) do
        if t.window then present[t.window.stable_id] = true end
    end
    -- A partner closed or left the monitor: back to the stack.
    if split and not (present[split.left] and present[split.right]) then
        splits[ws.id] = nil
        split = nil
    end

    -- Focusing a window outside the pair shows it alone. The split stays,
    -- and comes back when one of the pair is focused again.
    local front = front_of(ctx)
    local showing_split = split and (front == split.left or front == split.right)

    local left, right = halves(ctx.area)
    for _, t in ipairs(ctx.targets) do
        local id = t.window and t.window.stable_id
        local box = ctx.area
        if split and id == split.left then
            box = left
        elseif split and id == split.right then
            box = right
        end

        local shown = showing_split and (id == split.left or id == split.right)
            or (not showing_split and id == front)
        t:place(shown and box or parked(box))
    end
end

local function layout_msg(ctx, msg)
    -- An empty workspace, e.g. the active one after its last window closed
    -- while focus moved to the other monitor. Nothing to do; rejecting the
    -- message would show an error.
    local ws = workspace_of(ctx)
    if not ws then return true end

    -- Sent on every focus change, so the front window is shown.
    if msg == "focus" then
        return true
    end
    if msg == "stack" then
        splits[ws.id] = nil
        return true
    end
    if msg ~= "left" and msg ~= "right" then
        return false
    end

    local active = hl.get_active_window()
    if not active then return false end

    -- The partner is the most recently focused other window on the monitor.
    local focused, partner
    for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w and w.stable_id == active.stable_id then
            focused = w
        elseif w and w.focus_history_id >= 0
            and (not partner or w.focus_history_id < partner.focus_history_id) then
            partner = w
        end
    end
    -- Nothing to split with. Accepting the message avoids Hyprland's error
    -- notification; the recalculation it triggers changes nothing.
    if not (focused and partner) then return true end

    if msg == "left" then
        splits[ws.id] = { left = focused.stable_id, right = partner.stable_id }
    else
        splits[ws.id] = { left = partner.stable_id, right = focused.stable_id }
    end
    return true
end

hl.layout.register("stack", {
    recalculate = recalculate,
    layout_msg  = layout_msg,
})

hl.config({
    general = {
        layout = "lua:stack",
    },
})

-- Windows would otherwise slide in from where they are parked.
hl.animation({ leaf = "windowsMove", enabled = false })

-- Always present, so no other workspace is ever needed. There are no
-- workspace binds.
hl.workspace_rule({ workspace = "1", monitor = monitors.left, persistent = true, default = true })
hl.workspace_rule({ workspace = "2", monitor = monitors.right, persistent = true, default = true })

-- Show the newly focused window. The message goes to the layout of the
-- focused window's workspace. During a reload, workspaces briefly run the
-- default layout, which rejects the message with an error.
hl.on("window.active", function(w)
    if w and not w.floating and w.workspace
        and w.workspace.tiled_layout == "lua:stack" then
        hl.dispatch(hl.dsp.layout("focus"))
    end
end)
