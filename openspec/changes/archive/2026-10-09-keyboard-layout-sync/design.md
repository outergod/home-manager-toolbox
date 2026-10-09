## Context

See proposal.md (Why) for the findings. The current setup, from hyprland-desktop D7:

- Global input in `input.lua`: `kb_layout = "us,us"`, `kb_variant = ",dvorak"`. Every keyboard gets both groups.
- One `hl.device` block pins `splitkb.com-kyria-rev3` to plain `us`. With a single group, the toggle can't move it.
- Super+Tab in `binds.lua` runs `hyprctl switchxkblayout all next`, because Hyprland 0.56 has no Lua dispatcher for layouts.

Constraints:
- Hyprland's Lua API has no event for a keyboard being added or its layout changing (only `input.keyboard.key`), so the config can't react to hotplugged keyboards.
- Vicinae has no setting for the layout its virtual keyboard types in.
- The config also has to work on machines without the Kyria or the Preonic, e.g. a laptop whose built-in keyboard needs the software toggle.

## Goals / Non-Goals

**Goals:**
- Paste and snippet expansion from Vicinae work whatever the toggle is on.
- One Super+Tab press always leaves every toggleable keyboard on the same layout.

**Non-Goals:**
- A keyboard plugged in while the toggle is on Dvorak comes up on US until the next press. Catching the hotplug would need an event Hyprland's Lua API doesn't have.
- Terminals that paste with Ctrl+Shift+V (Ptyxis). Whether Vicinae sends the right shortcut there is a separate question.
- Noctalia's virtual keyboard (`hl-virtual-keyboard-…noctalia…`). It uses the virtual-keyboard protocol, where the client usually supplies its own keymap, and nothing is broken there.

## Decisions

### D1: Pin by device name, one list

`input.lua` keeps a list of devices that always use plain `us` and loops it through `hl.device`:

- `splitkb.com-kyria-rev3`: firmware Dvorak (existing)
- `drop-preonic`, `drop-preonic-keyboard`: switches between US and Dvorak in firmware, US by default. Pinning leaves the choice to the firmware, so a game on it never gets Dvorak because the toggle happened to be on. `drop-preonic` carries the letter keys (below); pinning `drop-preonic-keyboard` too does no harm.
- `vicinae-snippet-virtual-keyboard`: Vicinae's uinput device

The `-consumer-control` and `-system-control` devices only send media and power keys, so they don't need a pin.

The Preonic's names come from libinput in the Hyprland log: "Drop Preonic" (event10) and "Drop Preonic Keyboard" (event14), which Hyprland names `drop-preonic` and `drop-preonic-keyboard`. The letter keys come from `drop-preonic`. With `drop-preonic-keyboard` alone switched to Dvorak, typing on the Preonic was unchanged; with `drop-preonic` alone on Dvorak, it wasn't. `drop-preonic-keyboard` stays pinned anyway.

The comment on the list says why each kind is there: firmware layouts, and synthetic input whose keycodes assume US.

Alternatives:
- *Make Vicinae follow the active layout.* No setting for that exists. Its character map assumes the first group, and the device's group follows the toggle.
- *Match all synthetic keyboards generically.* Hyprland's device config matches exact names only, and Vicinae's is the only synthetic keyboard sending keycodes.

### D2: Super+Tab sets an absolute layout from Lua state

The bind becomes a Lua function holding a `dvorak` flag. Each press flips it and runs `hyprctl switchxkblayout all 1` or `… all 0`.

Alternatives:
- *Keep `next`.* That's the cause of the drift.
- *Read the current layout from a device* (`hyprctl devices -j`). The obvious reference, the `main` keyboard, is usually the Kyria, which is pinned and always reports index 0, so the toggle would stick on Dvorak. Picking the first device with two layouts works, but needs a JSON pipeline in a shell command for little gain.

Checked on Hyprland 0.56.2 (tasks 2.1): `hyprctl switchxkblayout all 1` prints `layout idx out of range of 1` for a pinned device, but carries on and switches the keyboards after it. Its exit code stays 0. So `all` is enough and nothing has to be switched by name.

With Lua state, the flag resets to US on a config reload. The next press then sets Dvorak on all keyboards, which is consistent even if the devices had kept another layout. At worst that costs one extra press.

Checked (tasks 2.3): a reload does not reset the indices. Keyboards on Dvorak stay on index 1, so the first press after a reload re-applies Dvorak and the second returns to US. Keyboards on US stay on 0, where flag and devices agree.

## Risks / Trade-offs

- [`switchxkblayout all 1` may reject single-layout devices (the pinned ones) as out of range, and possibly stop before switching the rest.] → Check before relying on it (tasks 2.1). If it fails, switch only the devices that have two layouts, by name, from the same Lua function.
- [Noctalia's indicator seems to follow the last layout event, not the main keyboard. If a pinned device's event comes last, the indicator may always read US.] → Check with the Kyria connected (tasks 3.3). If it's wrong, look at what Noctalia reads before changing the order.
- [Vicinae could start tracking the active layout in a later version, and then pinning would make it type wrong.] → The paste and snippet checks in tasks 3 catch it after an update. The pin is one list entry to remove.
- [Device names can change with firmware updates (Preonic) or Vicinae updates.] → A renamed device falls back to the toggle and nothing breaks, apart from what this change fixes. Names are taken from `hyprctl devices`.

## Migration Plan

`home-manager switch`. Hyprland reloads the config, which applies device blocks to connected keyboards (to verify in tasks 1.2). No re-login or Vicinae restart should be needed. Rollback is a generation rollback.
