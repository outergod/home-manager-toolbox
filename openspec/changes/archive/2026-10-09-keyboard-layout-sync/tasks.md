## 1. Pinned keyboards

- [x] 1.1 Confirm the Preonic's device names with `hyprctl devices` while typing on it, and note which device carries the letter keys in design.md D1. If the names differ from `drop-preonic` and `drop-preonic-keyboard`, use the actual ones
- [x] 1.2 In `desktop/hypr/input.lua`, replace the Kyria's `hl.device` block with a list of pinned device names (Kyria, Preonic, `vicinae-snippet-virtual-keyboard`) looped through `hl.device` with `kb_layout = "us"`, `kb_variant = ""`, commented as in D1. Verify after the reload that `hyprctl devices` shows `layout=us` and English (US) for each of them, without re-login or a Vicinae restart, and that `hyprctl configerrors` is empty

## 2. Absolute toggle

- [x] 2.1 Check how `hyprctl switchxkblayout all 1` treats the pinned single-layout devices: does it skip them, or does it report an error and leave later devices unswitched? Compare `hyprctl devices` before and after. If it stops early, switch the two-layout devices by name from the bind instead (design.md Risks), and record the result in design.md D2
- [x] 2.2 In `desktop/hypr/binds.lua`, replace the `switchxkblayout all next` bind with a Lua function that flips a `dvorak` flag and switches all keyboards to index 1 or 0 (D2), with the comment updated. Verify the drift scenario: put one toggleable device out of step with `hyprctl switchxkblayout <device> next`, press Super+Tab, and every toggleable keyboard in `hyprctl devices` is on the same index
- [x] 2.3 Run `hyprctl reload` while on Dvorak, then check `hyprctl devices` and press Super+Tab. All toggleable keyboards end up on one layout. Record in design.md D2 whether a reload resets the indices

## 3. Verification

- [x] 3.1 Vicinae paste: with Super+Tab on US, and again on Dvorak, paste a clipboard history item into Zed with Return. It is inserted both times. Verified in the terminal instead: Zed is in Vim mode, where Ctrl+V starts a visual block on either layout
- [x] 3.2 Vicinae snippets, if any are defined: expanding one inserts the right text on both US and Dvorak. None are defined, so not applicable
- [x] 3.3 Noctalia's layout indicator matches the toggleable keyboards' layout in `hyprctl devices` after each of several Super+Tab presses, with the Kyria connected. If it doesn't, find out what Noctalia reads and record it in design.md Risks
- [x] 3.4 Typing on the Kyria and on the Preonic gives the same characters on both toggle states
- [x] 3.5 Update the Purpose of `openspec/specs/keyboard-input/spec.md` to cover firmware-layout keyboards and synthetic input instead of the Kyria alone, and check that `openspec validate keyboard-layout-sync --strict` passes
