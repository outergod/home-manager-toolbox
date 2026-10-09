## 1. Focus after close

- [x] 1.1 Set `focus_on_close = "mru"` in `desktop/hypr/input.lua` (D1); verify with `hyprctl getoption input:focus_on_close` (int 2) after the reload
- [x] 1.2 Verify the spec scenario: on one monitor, open A, B and C in any order, focus A, then B, then C, and close C. B is in front and focused. Repeat with the most recently opened window not being B

## 2. No-window events

- [x] 2.1 In the `window.active` handler in `stack.lua`, treat `w.stable_id == nil` as "no window" and return early (D2), with a comment on why `if w` doesn't work; verify that switching the monitor's input away and back no longer shows `stack.lua:180: table index is nil`
- [x] 2.2 Audit `binds.lua` and `stack.lua` for other event-argument window objects tested with `if w`, and fix any found; record the result in design.md D2 if it differs from the audit already noted there

## 3. Workspace rules

- [x] 3.1 Drop `persistent = true` from the workspace 1 and 2 rules in `stack.lua`, keeping the `desc:` binding and `default = true`, and update the comment above them (D5); verify with `hyprctl workspacerules` (no persistent flag) and `hyprctl configerrors` (empty)

## 4. Reconcile on monitor changes

- [x] 4.1 Implement `reconcile()` in `stack.lua` following D3 steps 1–5: real monitors without `FALLBACK` and mirrors, a target workspace per monitor, silent moves (`follow = false`), focusing the most recently used windows, and restoring the `focus_order` snapshot; verify after the reload that the windows currently stranded on workspaces 2 and 3 are on one stack, the previously used window in front (`hyprctl workspaces` lists one workspace with windows)
- [x] 4.2 Trigger `reconcile()` from `monitor.added` and `monitor.removed` through one coalesced one-shot timer (about 500 ms), and once after the config loads (D4), without reading the event's monitor argument; verify that a reload causes no error and leaves the stack order unchanged
- [x] 4.3 Check the 50 ms timer watchdog: with all usual apps open (Steam, Zen, Emacs, Discord, Zed, terminal), run the input switch round trip five times; no "execution timed out" error. If it fires, split the moves across timer ticks (design.md Risks) and repeat

## 5. One BenQ

- [ ] 5.1 Remove the second BenQ (D6): its `hl.monitor` entry and the `right` field of the returned table in `monitors.lua`, and workspace 2's rule and `own_workspace` entry in `stack.lua`. Rename `monitors.left` to a name that doesn't imply a second monitor, and update the comments that describe two BenQs (`monitors.lua` header, the workspace rule comment in `stack.lua`). `stack.lua` is the only user of `monitors.left`/`right` today; check again with grep. Verify with `hyprctl workspacerules` (only workspace 1) and `hyprctl configerrors` (empty)

## 6. Verification

- [ ] 6.1 Only monitor leaves and returns: focus a window, switch the BenQ's input to the other machine and back. The same window is in front and focused, `hyprctl activeworkspace` is not an empty extra workspace, `hyprctl workspaces` shows no workspace with windows besides the shown one, and `hyprctl configerrors` is empty. Repeat with the screen going into standby (idle until DPMS off), then unlock
- [ ] 6.2 Closing after a merge: after 6.1, close the front window. The window focused before it comes to the front
- [x] 6.3 Two monitors: disconnecting one merges its windows into the other's stack by order of use; connecting it again shows an empty stack there, and Super+Shift+Left/Right moves a window over. **Not verifiable on this machine: the second BenQ was removed for good (D6). Verify the first time this configuration runs on a machine with two displays; until then covered by 6.1's single-monitor path as far as the code is shared.**
- [ ] 6.4 `openspec validate monitor-resilience --strict` passes, and design.md reflects any adjustments made during verification (delay, chunking, audit result)
