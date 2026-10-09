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

-- Focus order by stable ID, counted by the window.active handler below.
-- Hyprland's focus_history_id can't be relied on here: a new window can get
-- focus before it is added to the layout, and is then added with a stale
-- history ID, which put it behind the old front window.
local focus_order, focus_count = {}, 0

-- Whether window a was focused at least as recently as b. Windows focused
-- before a reload have no count; for them, Hyprland's focus history decides.
-- One that never had focus yet (history ID -1) just opened, and counts as
-- the most recent too.
local function more_recent(a, b)
    local ca, cb = focus_order[a.stable_id] or 0, focus_order[b.stable_id] or 0
    if ca ~= cb then return ca > cb end
    local ra = a.focus_history_id < 0 and -1 or a.focus_history_id
    local rb = b.focus_history_id < 0 and -1 or b.focus_history_id
    return ra <= rb
end

-- The most recently focused window.
local function front_of(ctx)
    local front
    for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w and (not front or more_recent(w, front)) then
            front = w
        end
    end
    return front and front.stable_id
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

-- Each BenQ starts on its own workspace, so one that connects next to the
-- other starts with an empty stack. Not persistent: a workspace kept for a
-- monitor that isn't connected would sit on another one as a second stack.
-- There are no workspace binds.
hl.workspace_rule({ workspace = "1", monitor = monitors.left, default = true })
hl.workspace_rule({ workspace = "2", monitor = monitors.right, default = true })

-- The same pairs by monitor description, as reconcile() sees them.
local own_workspace = {
    [(monitors.left:gsub("^desc:", ""))] = 1,
    [(monitors.right:gsub("^desc:", ""))] = 2,
}

-- Show the newly focused window. The message goes to the layout of the
-- active workspace, which is the focused window's. During a reload,
-- workspaces briefly run the default layout, which rejects the message
-- with an error. The active workspace is checked rather than the window's:
-- a window that has just opened has no workspace yet at this point.
hl.on("window.active", function(w)
    -- Focus moving to no window, e.g. when the last monitor disconnects,
    -- still comes with a window object, just with every field nil. So
    -- `if w` doesn't tell; the stable ID does.
    if w.stable_id == nil then return end
    if not w.floating then
        focus_count = focus_count + 1
        focus_order[w.stable_id] = focus_count
    end
    local ws = hl.get_active_workspace()
    if not w.floating and ws and ws.tiled_layout == "lua:stack" then
        hl.dispatch(hl.dsp.layout("focus"))
    end
end)

-- Brings whatever Hyprland made of a monitor change back to one stack per
-- connected monitor: windows on any other workspace join the stack of the
-- monitor that workspace is on, and each monitor shows its most recently
-- used window.
local function reconcile()
    -- FALLBACK is Hyprland's stand-in while no monitor is connected. Then
    -- there is nothing to show, and the run after the next monitor.added
    -- does the work.
    local real, home = {}, nil
    for _, m in ipairs(hl.get_monitors()) do
        if m.name ~= "FALLBACK" and not m.is_mirror then
            real[m.name] = m
            if m.focused or not home then home = m end
        end
    end
    if not home then return end

    -- Windows by monitor, and each monitor's most recently used one. A
    -- workspace on no connected monitor goes to the focused one.
    local windows, recent, latest = {}, {}, nil
    for _, w in ipairs(hl.get_windows()) do
        local ws = w.workspace
        if ws and not ws.special then
            local m = ws.monitor and real[ws.monitor.name] or home
            windows[m.name] = windows[m.name] or {}
            table.insert(windows[m.name], w)
            if not recent[m.name] or more_recent(w, recent[m.name]) then
                recent[m.name] = w
            end
            if not latest or more_recent(w, latest) then latest = w end
        end
    end

    -- The stack lives on the monitor's own workspace if it's there.
    -- Otherwise on the workspace of the most recently used window, not the
    -- active one: after the only monitor returns, that is the empty one
    -- Hyprland made for FALLBACK.
    local placed = {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if ws.monitor then placed[ws.id] = ws.monitor.name end
    end

    local target, moves = {}, {}
    for name, m in pairs(real) do
        local own = own_workspace[m.description]
        local used = recent[name] and recent[name].workspace.id
        target[name] = own and placed[own] == name and own
            or used and placed[used] == name and used
            or m.active_workspace and m.active_workspace.id
        for _, w in ipairs(windows[name] or {}) do
            if w.workspace.id ~= target[name] then
                table.insert(moves, { w = w, to = target[name] })
            end
        end
    end

    -- Nothing to do, e.g. on a reload. Focusing would warp the pointer.
    local settled = #moves == 0 and (not latest or hl.get_active_window())
    for name, m in pairs(real) do
        if recent[name] and not (m.active_workspace and m.active_workspace.id == target[name]) then
            settled = false
        end
    end
    if settled then return end

    -- Focusing below counts as use; the order from before stays.
    local order, count = {}, focus_count
    for id, n in pairs(focus_order) do order[id] = n end

    for _, move in ipairs(moves) do
        hl.dispatch(hl.dsp.window.move({
            workspace = move.to, window = "address:" .. move.w.address, follow = false,
        }))
    end

    -- Focusing a window shows its workspace on its monitor. The most
    -- recently used window overall goes last, so it ends up focused.
    for _, w in pairs(recent) do
        if w ~= latest then
            hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
        end
    end
    if latest then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. latest.address }))
    end

    focus_order, focus_count = order, count
end

-- Hyprland reshuffles monitors and workspaces in deferred steps after the
-- event, and switching the input produces several events in a row. One
-- timer, restarted by each, runs reconcile() once things have settled. The
-- events' monitor argument may already be empty, so it isn't read.
local RECONCILE_DELAY_MS = 500
local pending

local function schedule_reconcile()
    if pending and pending:is_enabled() then
        pending:set_timeout(RECONCILE_DELAY_MS)
    else
        pending = hl.timer(reconcile, { timeout = RECONCILE_DELAY_MS, type = "oneshot" })
    end
end

hl.on("monitor.added", schedule_reconcile)
hl.on("monitor.removed", schedule_reconcile)

-- Also repairs a session left broken before this config was loaded.
schedule_reconcile()
