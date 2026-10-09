## Context

The window model is hyprland-desktop's D5 (archived 2026-10-08): a Lua layout `lua:stack` in `desktop/hypr/stack.lua`. One workspace per monitor, front window shown, the others parked below all monitors. Front-ness comes from `focus_order`, a global Lua table `stable_id → counter` that a `window.active` handler bumps. Workspaces 1 and 2 are persistent and bound to the left and right BenQ by `desc:`. The right BenQ has since been removed for good, and the configuration is meant to be reused on other machines with other displays (D6). See proposal.md for the four failures and their causes in Hyprland 0.56.2.

Hyprland behaviour this design relies on, all checked in the v0.56.2 source:
- `input:focus_on_close` has three modes: `0` "next" (ask the layout), `1` "cursor" and `2` "mru". In "mru", Hyprland walks its window focus history, newest first, and takes the first window in the same layout space (`CAlgorithm::getNextCandidate`).
- Lua event arguments that are windows are never `nil`. `CLuaWindow::push` always creates an object. For "no window", every field reads `nil`. Query functions (`hl.get_active_window()` etc.) and `target.window` in layouts do return a real `nil`.
- When the last monitor is removed, `CFallbackStateKeeper` creates a headless output named `FALLBACK`. Its default workspace is the first free ID not bound to another monitor, which today is 3. When a real monitor connects, Hyprland moves its default workspace onto it, pulls in orphaned workspaces, and switches to the workspace that monitor last showed. Later (`doLater`) it destroys `FALLBACK` and moves that output's workspace onto the real monitor, where it ends up active.
- `hl.dsp.window.move({ workspace = …, window = …, follow = false })` moves a window without focusing it.
- Lua callbacks run under a wall-clock watchdog: 50 ms for layout, event and timer callbacks.

## Goals / Non-Goals

**Goals:**
- One mechanism that brings any monitor configuration back to "one stack per connected monitor", no matter how Hyprland got there.
- Keep the order of use across merges, using the existing `focus_order`.

**Non-Goals:**
- Preventing Hyprland from creating the `FALLBACK` workspace. A workspace owned by `FALLBACK` always lands in front on the returning monitor (see Context), so prevention isn't possible from config.
- Remembering a window's original monitor (decided: windows stay where they are when a monitor returns).
- Avoiding the brief flash of the wrong stack while Hyprland reshuffles.

## Decisions

### D1: Focus after close comes from Hyprland's MRU

Set `input.focus_on_close = 2` ("mru") in `input.lua`. The Lua config rejects the name: the option is an integer, and the binding takes only an integer or a bool. The `window.active` handler then sees Hyprland's choice, and that choice matches `focus_order`. Parked windows can't be hovered, so Hyprland's focus history contains only real focus changes, the same events that feed `focus_order`.

- *Alternative:* handle `window.close` in Lua and focus the window with the highest `focus_order`. Rejected: Hyprland focuses its own candidate first, so there would be two focus changes, a visible flash, and a race over which one wins.
- *Alternative:* make the layout answer "next candidate". Not possible; Lua layouts have no hook for it.

### D2: "No window" is checked by `stable_id`

The `window.active` handler treats `w.stable_id == nil` as "no window" and returns early, instead of testing `w`. This applies to window objects that come in as event arguments. Query results and layout targets keep their `nil` checks, which work. `binds.lua` was audited: its window values all come from `hl.get_active_window()`, `hl.get_workspace_windows()` and `hl.get_monitors()`, so it isn't affected.

### D3: Reconcile after monitor changes

`stack.lua` gets a `reconcile()` function and runs it on `monitor.added` and `monitor.removed`, and once after the config loads. Running it at load also repairs a session that is already broken, such as today's windows stranded on workspaces 2 and 3, as soon as the change is applied.

Per run:
1. **Real monitors** = `hl.get_monitors()` without `FALLBACK` and without mirrors. If there are none, stop. While nothing is connected there is nothing to show, and the run that follows `monitor.added` does the work.
2. **Target per monitor**: the BenQ's own workspace (1, D5) if it is on that monitor. Otherwise, e.g. for another display, the workspace on that monitor that holds its most recently used window (highest `focus_order` count). If none of its workspaces has windows, use its active workspace. Windows on a workspace with no real monitor (`FALLBACK`'s, if it still exists) count towards the focused real monitor.
3. **Move** every window on a non-special workspace that isn't a target to the target of the monitor its workspace is on, with `follow = false`.
4. **Show**: focus each monitor's most recently used window, the overall most recently used one last. This switches each monitor to its target. Empty, non-persistent leftovers (the `FALLBACK` workspace) are then destroyed by Hyprland.
5. **Restore** the `focus_order` snapshot taken before step 3. Step 4's focus changes would otherwise reorder the stacks. Only the last focused window is really the most recent, and it already has the highest count.

If nothing needs moving, every monitor with windows already shows its target, and a window has focus, the run stops before step 3. Otherwise every reload would focus a window and warp the pointer to it.

Because `focus_order` is global, a merged stack is ordered by use across both former stacks without extra bookkeeping. Windows focused before the last reload have no count; they fall back to Hyprland's `focus_history_id`, as `front_of` already does.

- *Alternative:* target = the workspace of the monitor's most recently used window, for the BenQs too. Rejected during implementation, while the second BenQ was still configured: in the session this change was applied to, workspace 2 was active on the left BenQ. The whole left stack would have moved into workspace 2, which is bound to the right BenQ, and Hyprland would carry it over when that monitor connects. That breaks "a monitor connects next to another" and D5.
- *Alternative:* target = the monitor's active workspace. Rejected: after a round trip, the active workspace is the transient `FALLBACK` workspace. All windows would move into it, and workspace IDs would keep climbing.
- *Alternative:* move windows directly in the event handler. Rejected: Hyprland finishes its reshuffle in deferred callbacks after the event, so the handler would see an intermediate state.

### D4: Reconcile runs on a short coalesced timer

The event handlers only (re)start a single one-shot `hl.timer` (about 500 ms). The callback runs `reconcile()` once Hyprland has settled. Several hotplug events in a row (the input switch produces remove/add/remove/add) collapse into one run. The handlers don't read their monitor argument. A removed monitor's object may already be empty (D2's pitfall), so `reconcile()` reads the current state itself.

### D5: Workspace rules lose `persistent`

Workspaces 1 and 2 keep their `desc:` monitor binding and `default = true`, so a BenQ that connects next to another one starts on its own, empty workspace (spec: a monitor connects next to another). They drop `persistent = true`, which was what kept an empty workspace 2 alive with no monitor to show it. The comment "Always present, so no other workspace is ever needed" is updated to match.

With the second BenQ gone (D6), workspace 2's rule is removed as well. Workspace 1 stays bound to the remaining BenQ. Any other display starts on whatever workspace Hyprland gives it, which is enough for "a monitor connects next to another", because that workspace is new and empty.

### D6: One BenQ, a general model

`monitors.lua` names only the remaining BenQ. The catch-all rule (`output = ""`, preferred mode, automatic position and scale) covers every other display. `stack.lua` drops workspace 2's rule and its `own_workspace` entry. Nothing else in `reconcile()` or `binds.lua` changes: the multi-monitor paths (merging a disconnected monitor's stack, an empty stack for a monitor that connects next to another, moving windows between monitors) stay. The configuration is meant to be reused on machines with more than one display, such as a laptop or a Steam Deck with an external screen, and that code is already written for any set of monitors.

- *Alternative:* commit to a single monitor: drop the multi-monitor logic from `reconcile()` and the monitor binds. Rejected: it would break reuse on machines with more displays, and the code is in place and costs nothing with one monitor.
- *Alternative:* keep the second BenQ's entry for the case it ever returns. Rejected: dead configuration, and its workspace rule would bind workspace 2 to a monitor that never appears.

## Risks / Trade-offs

- [The 50 ms timer watchdog covers the dispatches inside `reconcile()`, and every move triggers a layout recalculation, right after a modeset when the system is visibly slow (libinput lag warnings of 100–180 ms)] → Keep the work in Lua small. If the watchdog fires during verification, split the moves across successive timer ticks, one window per tick.
- [The 500 ms delay is a guess at when Hyprland has settled] → Verify with the input-switch reproduction. If a later reshuffle still shows a wrong workspace, run reconcile again on `workspace.created`, or lengthen the delay.
- [A stale `FALLBACK` workspace with windows: something opened while no monitor was connected, e.g. an autostarted app] → Step 3 moves it like any other non-target workspace.
- [The user sees the wrong stack, or an empty one, for up to about 500 ms after the monitor returns] → Accepted (Non-Goals).
- [The multi-monitor paths can't be verified on this machine, which has one monitor for good (D6)] → They are covered by the single-monitor round trip only as far as `reconcile()` shares code. Verify them the first time this configuration runs on a machine with two displays.

## Migration Plan

Apply with `home-manager switch` (the Lua modules are out-of-store symlinks, so saving is enough and Hyprland reloads by itself). The load-time `reconcile()` folds the currently stranded workspaces into one stack. To roll back, revert the commit; Hyprland reloads the previous config.
