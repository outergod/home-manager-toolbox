## Why

The stack window model from hyprland-desktop assumes two monitors that are always connected. Daily use (hyprland-desktop task 11.1) showed that neither holds. The desk now has one BenQ, and the second one is gone for good. The same configuration is meant to be reused on other machines, such as a laptop or a Steam Deck with an external screen, so the model can't assume any particular set of monitors either. The BenQ and its USB hub are regularly switched to another machine, and the monitor drops off when it goes into standby, so Hyprland sees the only monitor disappear and come back several times a day. Every round trip leaves the session in a broken state. Closing a window also brings the wrong one to the front, independent of monitors.

Findings (traced in Hyprland 0.56.2's source):
- **Wrong window after a close.** When the focused window closes, Hyprland picks the next focus itself. With `input:focus_on_close = 0` ("next", the default) it asks the layout. Lua layouts answer with the target added most recently, not the one focused most recently (`CLuaTiledAlgorithm::getNextCandidate`). The stack layout then puts that window in front, because it follows focus.
- **Lua error after a monitor round trip** (`stack.lua:180: table index is nil`). When focus is cleared, Hyprland emits `window.active` with no window. The Lua binding still passes a window object (`CLuaWindow::push` always creates one), and all its fields read `nil`. So `if w` doesn't guard, and `focus_order[w.stable_id]` fails.
- **Empty workspace after a round trip.** With no monitor left, Hyprland creates a headless `FALLBACK` output. Its default workspace can't be 1 or 2, which are bound to the BenQs, so Hyprland creates workspace 3. When the BenQ returns, the fallback's workspace moves onto it and ends up in front, empty. Reproduced by switching the monitor's input back and forth: `hyprctl activeworkspace` reported workspace 3.
- **Stranded windows.** Workspace 2 is persistent and bound to the right monitor. Without that monitor, it sits on the left monitor as a second stack, and the user can only reach it through the launcher. Windows opened on workspace 3 strand the same way.

## What Changes

- Closing the focused window brings the most recently focused remaining window on that monitor to the front.
- Event handlers in the Hyprland Lua config tolerate "no window" events. A monitor round trip produces no configuration errors.
- The window model follows the monitors that are connected: none, the BenQ alone, or any mix of displays, such as a laptop panel with an external screen. Each connected monitor keeps exactly one stack. Windows from a stack whose monitor is gone, and from any extra workspace Hyprland created meanwhile, join a remaining stack in their order of use. After a round trip, the most recently used window is in front.
- A monitor that (re)appears starts with an empty stack. Windows don't move back to it on their own; Super+Shift+Left/Right moves them.
- The workspace rules no longer keep a stack alive for a monitor that isn't connected.
- The monitor configuration names only the one BenQ. The second BenQ's entry and its workspace rule are removed. Any other display is placed automatically and gets a stack like any monitor.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `window-management`: the monitor arrangement describes the one BenQ, with any other display placed automatically; one stack per *connected* monitor, including what happens when monitors leave and return; closing the front window shows the previously focused one; no windows are left on hidden workspaces.
- `hyprland-session`: no configuration errors from monitor changes, not just at login.

## Impact

- `desktop/hypr/input.lua`: focus on close.
- `desktop/hypr/stack.lua`: `window.active` guard, workspace rules (workspace 2's removed), and reconciling stacks on monitor changes.
- `desktop/hypr/monitors.lua`: the second BenQ removed.
- `desktop/hypr/binds.lua`: audit for the same "window is never nil" pitfall (`move_to_monitor`, `swap_monitors`, `front_window`).
- No Nix or package changes. Hyprland, hypridle and hyprlock come from the image as before.
