## Why

Pasting from Vicinae's clipboard history does nothing in any app. Vicinae names the right target window and sets the clipboard, but the paste keystroke never arrives as Ctrl+V. Shift+Return, which only copies, works. The same investigation showed that Super+Tab leaves keyboards on different layouts, and the bar's layout indicator reports the opposite of what some devices use. The configuration is also meant for other machines, such as a laptop, where the software Dvorak toggle is the only way to get Dvorak.

Findings (Vicinae 0.29, Hyprland 0.56):
- **Vicinae types through its own keyboard.** `vicinae-input-server` creates a uinput device, `vicinae-snippet-virtual-keyboard`, and sends the paste shortcut as raw keycodes for a US layout. Hyprland treats the device like any other keyboard: it gets the global `us,us` / `,dvorak` keymap and follows Super+Tab. On Dvorak, the key Vicinae means as V produces K, so apps receive Ctrl+K. The journal shows every paste up to the keystroke succeeding (`Pasting to …`, `Clipboard set via ext-data-control`), with no focus-transfer timeout, so the stack layout is not involved.
- **Super+Tab steps each device on its own.** `hyprctl switchxkblayout all next` advances every keyboard's own layout index. Devices that reappear, e.g. USB devices after the monitor's input is switched, start at index 0 whatever the others are on. `hyprctl devices` showed two groups a step apart: power buttons and the virtual keyboards on Dvorak, the USB devices on US. `next` keeps them apart for good.
- **The Preonic switches between US and Dvorak in firmware**, US by default, but follows the toggle today. Its firmware Dvorak with the toggle on Dvorak gives Dvorak twice over.

## What Changes

- The Drop Preonic joins the Kyria rev3 on plain US, so its own firmware setting alone decides its layout. The toggle doesn't reach either.
- Vicinae's virtual keyboard stays on plain US, so its paste and snippet keystrokes produce the keys Vicinae intends.
- Super+Tab sets one layout on every keyboard the toggle reaches, instead of stepping each one. One press brings keyboards that drifted apart back together.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `keyboard-input`: the toggle sets one layout on all toggleable keyboards; the Preonic is pinned to US like the Kyria; synthetic keyboards stay on US.

## Impact

- `desktop/hypr/input.lua`: device blocks for the Preonic and Vicinae's virtual keyboard next to the Kyria's.
- `desktop/hypr/binds.lua`: Super+Tab switches to an explicit layout index.
- No Nix or package changes. Vicinae's configuration is unchanged.
