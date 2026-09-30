## Context

See proposal.md for motivation and scope. This section records the facts about the host, the image and the pinned inputs that shape the approach.

**Image (bazzite-hyprland, Fedora 44)**
- Provides hyprland 0.56.2 (Lua config), hyprlock, hypridle, xdg-desktop-portal-hyprland, hyprpolkitagent, uwsm and hyprland-guiutils. API stubs are at `/usr/share/hypr/stubs/hl.meta.lua` and an example config at `/usr/share/hypr/hyprland.lua`.
- The session entry `hyprland-uwsm.desktop` runs `uwsm start -e -D Hyprland hyprland.desktop`. uwsm's session target is therefore `wayland-session@hyprland.desktop.target`, which GNOME never reaches.
- The image ships `hypridle.service` and `hyprpolkitagent.service` in `/usr/lib/systemd/user/`. Neither is enabled for any target (`/etc/systemd/user/graphical-session.target.wants` only has `fumon` and `ntfs-nag`).
- The keyring autostart for Hyprland (`gnome-keyring-secrets-hyprland.desktop`, `OnlyShowIn=Hyprland`) comes from the image.

**Pinned Home Manager**
- `wayland.windowManager.hyprland.configType` is an enum of `"hyprlang"` and `"lua"`. The default depends on `stateVersion`: it is `hyprlang` for our 25.05, so `lua` must be set explicitly.
- With `package = null`, HM still generates `hypr/hyprland.lua`. It does not generate `hypr/.luarc.json` and does not reload the config on change.
- `extraLuaFiles` modules are `require`d before `settings` are rendered, after HM prepends `$XDG_CONFIG_HOME/hypr` to `package.path`.
- `wayland.systemd.target` (default `graphical-session.target`) is the target that noctalia, hypridle and other modules bind their units to. vicinae has its own `systemd.target` option, and walker and elephant hardcode `graphical-session.target`, so `shell.nix` overrides their units.
- `services.hypridle` and `programs.hyprlock` accept `package = null`, which writes the config only and creates no unit. `services.hyprpolkitagent`'s package is not nullable, so that module can't be used.

**Pinned nixpkgs**
- DMS 1.6.2 is Quickshell/Qt with a Go CLI; nixpkgs wires its lock screen to Nix's `pam`.
- Noctalia 5.1.0 (`noctalia`) is a native C++ rewrite linking `pam`, `polkit` and `libGL`. The older `noctalia-shell` 4.7.7 is Quickshell-based.
- Vicinae 0.29, Walker 2.17 with Elephant 2.22, foot 1.28 and Ghostty 1.3 are available, and all have HM modules. DMS's HM module lives only in its own flake.

**Host state**
- GNOME's `monitors.xml` has HDMI-1 at x=0 (primary, left) and DP at x=1920 (right), both 3840x2160 at scale 2. The panels are the BenQ PD3200U units from the old config (serials V5H01247019 and M9H01833019). Connector names have changed before.
- `~/.config/autostart` has Bitwarden and Vesktop (both written by the portal, `X-XDP-Autostart`) and Steam.
- Emacs and Zed launch through `distrobox-enter -n nix`. `~/.local/share/applications/emacs.desktop` and `emacsclient.desktop` are chezmoi-managed. `nix-dev.zed.Zed.desktop` was exported by distrobox. The host profile adds `dev.zed.Zed.desktop` and Emacs's own entries.
- chezmoi (`outergod/dotfiles`) manages writable dotfiles alongside HM.

## Goals / Non-Goals

**Goals:**
- Each phase is testable on its own, with GNOME as the fallback session throughout.
- Lua iteration doesn't need a `home-manager switch` for every edit.
- The shell tryout can be switched between candidates with a one-line change and rolled back.

**Non-Goals:**
- Changing the image. If a shell's own lock screen were ever wanted, the shell would have to ship in the image; that is a separate change.
- Hyprland plugins (hyprpm).
- Multi-host abstraction beyond the keyboard fallback. The config is written for this host and kept portable only where it is free.

## Decisions

### D1: Repository layout

`home.nix` imports a `desktop/` directory with one Nix module per concern:

| Module | Covers |
|---|---|
| `hyprland.nix` | HM hyprland module, uwsm env, `.luarc.json` |
| `session.nix` | target scoping, image unit links, autostart |
| `lock.nix` | hypridle and hyprlock settings |
| `shell.nix` | tryout switch, shell and launcher |
| `tools.nix` | screenshots, clipboard, automount, terminal |
| `container.nix` | dev container start, desktop-entry cleanup |
| `theme.nix` | look (last phase) |

Static Lua lives in `desktop/hypr/`.

**Why:** `home.nix` is already long, and each phase touches mostly one module.

**Alternative rejected:** a single file.

### D2: Lua config, HM-generated entry, live-linked modules

- Set `configType = "lua"`, `package = null`, `portalPackage = null`, `systemd.enable = false`.
- HM generates `hyprland.lua` as a thin entry point: it sets `package.path` and `require`s one `desktop` module, which loads the rest in an explicit order.
- The static Lua modules are linked with `config.lib.file.mkOutOfStoreSymlink` from `~/.config/home-manager/desktop/hypr/`. Saving a file then triggers Hyprland's own autoreload, with no switch. This matters most for the layout work in D5.
- A small generated module (`nix.lua`, via `extraLuaFiles`, `autoLoad = false`) exposes Nix-derived values to the static Lua: store paths of the launcher, terminal and screenshot tools, and later the palette.
- HM writes a hand-made `.luarc.json` that points at `/usr/share/hypr/stubs`.
- An `onChange` hook runs `/usr/bin/hyprctl reload`, since HM skips its own reload when `package = null`.

**Alternatives rejected:**
- Everything in `settings` via `mkLuaInline`: the layout and event handlers would become Lua embedded in Nix strings.
- Plain `xdg.configFile` without the HM module: equally viable, but loses `extraLuaFiles` and settings merging from other modules for no gain.
- In-store Lua: reproducible, but needs a switch per edit. It can be revisited once the config is stable.

### D3: Session scoping

- **Hyprland-only services:** set `wayland.systemd.target = "wayland-session@hyprland.desktop.target"` globally, so every HM-generated desktop service binds to the Hyprland session only.
- **Image services:** link `hypridle.service` and `hyprpolkitagent.service` into `~/.config/systemd/user/wayland-session@hyprland.desktop.target.wants/` using out-of-store symlinks to `/usr/lib/systemd/user/`. The image units stay the source of truth. Each linked unit gets a drop-in with `After=` and `PartOf=` the session target. Without it, the target is implicitly ordered after the units it wants. Together with the image units' `After=graphical-session.target` and uwsm's `Before=graphical-session.target`, that forms an ordering cycle, and `uwsm stop` fails with `TransactionOrderIsCyclic`.
- **Session-independent service:** the dev container unit (D11) uses `default.target`.
- **Environment:** Hyprland-specific variables go in `~/.config/uwsm/env-hyprland` (HM `xdg.configFile`).
- **Verification rule:** after each switch, no HM-generated desktop unit may be wanted by `graphical-session.target`. Tasks include a grep check.

**Alternative rejected:** `exec` from the Lua config. It gives no restart-on-failure, no journal unit and no ordering.

### D4: Locking, idle and polkit

- **hypridle** (`services.hypridle`, `package = null`, settings only):
  - `lock_cmd = pidof hyprlock || /usr/bin/hyprlock`
  - `before_sleep_cmd = loginctl lock-session`
  - `inhibit_sleep = 3`
  - `after_sleep_cmd` turns DPMS back on using the 0.56 dispatch syntax
  - listeners: 900 s runs `loginctl lock-session`, 1200 s turns DPMS off (DPMS back on at resume)
  - D-Bus and Wayland inhibitors are honoured
- **hyprlock** (`programs.hyprlock`, `package = null`): input field with `fade_on_empty = false`. It is themed in the look phase.
- **Hyprland:** `misc.allow_session_lock_restore = true`. Super+L runs `loginctl lock-session`.
- **Automatic idle inhibit:** a window rule inhibits idle while any window is fullscreen. Manual inhibit ("caffeine") comes from the chosen shell or launcher and must work through the Wayland idle-inhibit protocol (tryout criterion). If none does, a small toggle script inhibits hypridle through `systemd-inhibit`.
- **Polkit:** the image's hyprpolkitagent via D3. Shells' polkit agents stay off.
- **Crash recovery from a TTY** (verified in task 4.9):
  - If hyprlock dies, Hyprland stays locked and shows its crash screen, which takes no input.
  - Restore with `hyprctl --instance 0 eval 'hl.dispatch(hl.dsp.exec_cmd("/usr/bin/hyprlock"))'`, then switch back and unlock.
  - `loginctl lock-sessions` does not work from a TTY: it needs polkit authorization, and no agent runs there. Plain `loginctl lock-session` locks the TTY's own session, not Hyprland's.
  - After switching VTs, release all keys before typing the password. An earlier attempt rejected the typed password, probably because of modifiers stuck from the VT switch.

### D5: Window model: a custom Lua "stack" layout

- **Workspaces:** one persistent workspace per monitor.
  - Workspace 1 is on the left monitor and workspace 2 on the right.
  - Monitors are matched by `desc:` (BenQ serial), not by connector.
  - There are no workspace keybinds.
- **The layout** is registered with `hl.layout.register("stack", provider)`.
  - **Stack mode (default):** the most recently focused window gets the full `ctx.area`. The area excludes the bar's reserved zone, so the bar stays visible.
  - **Parking:** every other window keeps its size but is placed far below all monitors, where it is neither drawn nor reachable by the pointer. Hyprland finds the tiled window under the pointer without regard to z-order, so overlapping tiled windows would take hover focus and clicks from the front window (found after the spike). A `window.active` handler sends a `focus` layout message, so the layout recalculates and shows the newly focused window. The parked box is enlarged by `gaps_in`, so a window keeps its exact size and apps don't re-layout on each switch. The `windowsMove` animation is disabled, because windows would otherwise slide in from where they are parked.
  - **Split mode:** entered per workspace through `layout_msg`. The focused window takes the requested half; the most recently used other window on that workspace (lowest `focus_history_id`) takes the other half. The rest are parked. If a window outside the pair is focused, it fills the monitor and the pair is parked. The split is kept, and focusing either window of the pair shows it again.
  - **Leaving split mode:** Super+Up returns to stack mode. The mode also ends when either split window closes or leaves the monitor.
  - **State:** kept in Lua per workspace ID (keyed by window `stable_id`, which is never reused) and checked against the targets on each recalculation.
- **Floating:** dialogs (modal, transient, fixed-size, portal file pickers, polkit and pinentry) float centred and are never handed to the layout. Hyprland floats modal and transient windows by default; explicit rules cover the known stragglers. There is no blanket maximize or fullscreen rule. Maximize requests are suppressed, which is harmless because tiled windows already fill the area.
- **Focus:**
  - `follow_mouse = 1`, with cursor warps on programmatic focus. When the launcher raises a window on the other monitor, the cursor lands there and focus-follows-mouse doesn't snap back.
  - Windows never move when raised.
  - Alt+Tab focuses the previously focused window.
- **Fullscreen:** apps' own fullscreen requests are honoured (true fullscreen hides the bar). Super+F toggles true fullscreen.
- **Spike first:** before building the layout, check that
  - the provider can tell which workspace it is recalculating (for per-workspace state)
  - z-order of overlapping tiled windows follows `bring_to_top`
  - `layout_msg` is reachable from a keybind
- **Fallbacks, in order:**
  1. The built-in `scrolling` layout with `column_width = 1.0`: full-width columns act as a stack, and a split sets two columns to 0.5.
  2. dwindle with auto-grouping (groups act as a tabbed stack), with splits by moving a window out of its group.
- **Spike results (task 6.1, Hyprland 0.56.2):** the stack layout is viable, so the fallbacks aren't needed.
  - A registered layout is selected as `lua:<name>` (in `general.layout` or a workspace rule's `layout`), not by its bare name. A workspace rule changes the layout of an existing workspace immediately. Reload clears registered providers, and the config registers them again.
  - (a) `ctx` has only `area`, `targets` and the geometry helpers, with no workspace field. Each workspace gets its own algorithm instance, and every target's `window.workspace` is set, so the workspace comes from `ctx.targets[1].window.workspace.id`. `focus_history_id` is current inside `recalculate`.
  - (b) Hyprland draws the focused window above the other tiled windows, but only while it has focus. Once focus moves to the other monitor, the real z-order applies again. `bring_to_top` (no argument: the active window) sets that z-order, and dispatching it from a `window.active` handler works. Z-order turned out not to be enough, though: the pointer still reaches hidden windows (see Parking above). The built-in `monocle` layout avoids that by marking back windows invisible, which Lua layouts can't do. Only `place` and `set_box` are available, and both animate.
  - (c) `hl.dsp.layout(msg)` reaches the active workspace's provider as `layout_msg(ctx, msg)`, with the same `ctx`. Returning `true` triggers a `recalculate`. Keybinds take the same dispatcher.
  - Hyprland 0.56 also ships a built-in `monocle` layout. It wasn't needed, because the Lua layout covers both modes.

### D6: Keybindings

| Keys | Action |
|---|---|
| Ctrl+Space | omnibox (Cmd+Space on the Kyria in Mac mode, as on macOS) |
| Super+Space | window switcher (the launcher's list of open windows) |
| Super+Q | close window |
| Super+L | lock (`loginctl lock-session`) |
| Super+Left / Right | split: focused window to the left / right half |
| Super+Up | back to full stack |
| Super+Shift+Left / Right | move window to the other monitor |
| Super+Down | swap the front windows of both monitors |
| Super+F | toggle true fullscreen |
| Super+Tab | toggle US / Dvorak (not on the Kyria) |
| Alt+Tab | previous window |
| Print | screenshot UI |
| Super+LMB / RMB drag | move / resize floating windows |
| Media and volume keys | work while locked (`locked = true`) |

Old workspace, special-workspace and pseudo-tiling binds are dropped.

### D7: Keyboard layouts

- Global input: `kb_layout = "us,us"`, `kb_variant = ",dvorak"`, `compose:menu` carried over. Super+Tab cycles the layout on all keyboards.
- A device block for the Kyria rev3 pins it to plain `us`. `hyprctl devices` confirms the name `splitkb.com-kyria-rev3`, the same as in the old config. Its media keys come from a separate `-consumer-control` device, which needs no block.
- 0.56 has no Lua dispatcher for switching layouts, so Super+Tab runs `hyprctl switchxkblayout all next`. With a single layout, the Kyria stays on it.

### D8: Shell and launcher tryout

- **Selection:** a local option in `shell.nix`, `desktop.shell = "dms" | "noctalia" | "none"` and `desktop.launcher = "builtin" | "vicinae" | "walker" | "none"`. `builtin` requires a shell. Each candidate's commands reach the binds through `nix.lua` (`desktop.nixLua`): `launcher` (Ctrl+Space) and, where it has one, `windows` (Super+Space): Vicinae's Switch Windows deeplink, Noctalia's launcher prefilled with `/win `, Walker's windows provider. DMS's launcher has no window list. Only the selected combination is installed and started (bound to the Hyprland target). Switching is a one-line edit plus a switch, and rollback is a generation rollback.
- **Decision (task 8.6): Noctalia with Vicinae.** Noctalia reaches the old waybar look through config alone, keeps its settings-screen changes in a separate file, and passes the whole checklist. Vicinae lists every window, raises windows behind others, and offers contextual actions. The switch and the other candidates (DMS, Walker with Elephant) were removed from `shell.nix`; their results stay under "Tryout results" below. `shell.nix` now configures Noctalia and Vicinae directly and still hands the launcher commands to `nix.lua`.
- **Packaging:** DMS starts from the nixpkgs package with our own unit, so no new flake input is needed. DMS's flake and its HM module are adopted only if DMS wins and the module adds value.
- **GPU drivers:** the candidates render with GL. They find nixpkgs' Mesa through `/run/opengl-driver` (HM `targets.genericLinux.gpu`), with no wrapper. `dms` is wrapped only to put `qs` on PATH, since the nixpkgs package doesn't bring Quickshell along.
  - **Why not nixGL (found in task 8.2):** the nixGL wrapper sets `LD_LIBRARY_PATH` (Nix Mesa, libstdc++), and everything the wrapped program starts inherits it. Host C++ binaries then fail to load, e.g. DMS's `/usr/bin/hyprctl reload` (`GLIBCXX_3.4.35 not found`), and host apps started by a shell directly would too. nixGL's own nixpkgs pin also shipped an older libstdc++ than current packages need, so Noctalia didn't load at all.
  - **Setup:** `sudo non-nixos-gpu-setup` on the host installs a tmpfiles.d rule for the link and a gcroot. It is needed once, and again when nixpkgs' Mesa changes; activation warns when it is due.
  - **Container:** the `nix` distrobox has its own `/run`, and container root can't write the host's gcroots, so the setup script can't run there. A separate oneshot unit, `distrobox-nix-gpu` (after `distrobox-nix`), runs `podman exec --user root nix ln -sfn <drivers> /run/opengl-driver`. It changes with the drivers, so a switch restarts it and updates the link; it never starts or stops the container. This covers Zed, which was the only nixGL-wrapped app before.
- **Guardrails as implemented:**
  - DMS: own unit with `DMS_DISABLE_POLKIT=1` (its only switch). `settings.json` stays native and writable, since a read-only file makes the settings screen drop all changes. An activation step forces the guardrail keys back in on each switch: `loginctlLockIntegration = false` (ignore logind Lock and suspend), `customPowerActionLock = "loginctl lock-session"` (every lock button), `lockBeforeSuspend`/`lockAtStartup = false`, all idle timeouts 0. DMS has no way to turn its locker off entirely.
  - Noctalia: HM `config.toml` holds only the guardrails (`lockscreen.enabled = false`, `shell.polkit_agent = false`, idle behaviours off, a `command` session row for lock). The settings screen writes to `~/.local/state/noctalia/settings.toml`, which overrides config.toml.
  - Both try to own `org.freedesktop.ScreenSaver`; their units start after `hypridle.service` so hypridle keeps it.
- **Guardrails (fixed, not tryout options):** the shell's lock screen, polkit agent and idle manager are disabled. Every "lock" action in the shell calls `loginctl lock-session`. If a shell can't disable its polkit agent or redirect its lock action, it fails the tryout.
- **Checklist,** applied to each combination:
  1. Works with Hyprland 0.56: window list, focus, workspaces, events.
  2. Guardrails hold: no second polkit agent registered, lock goes through hyprlock, no shell idle timers.
  3. Caffeine actually stops hypridle from locking.
  4. Launcher: one entry per window, apps, prefixes for calculator, clipboard, files and power; raising doesn't move windows.
  5. Bar per monitor with volume, Bluetooth, network and tray.
  6. Notifications with do-not-disturb.
  7. Screenshot UI quality (D10).
  8. Config ownership: can Nix defaults and settings-screen changes coexist, where are the changes stored, and does an upgrade break the config?
  9. Theming: does the shell write GTK, Qt or terminal theme files, and can that be turned off?
- **Record:** results and the final choice are recorded in this document (a "Tryout results" section) before phase 4 is closed.
- **Fallback if both shells fail:** individual tools, meaning waybar, swaync and awww with the winning launcher.

### Tryout results (task 8.5)

**Shells.** Both pass the guardrails (criterion 2): no second polkit agent, hypridle keeps `org.freedesktop.ScreenSaver`, and the shell's lock action and suspend/resume both show hyprlock.
- **DMS:** works with 0.56's Lua config. It regenerates `~/.config/hypr/dms/layout.lua` and runs `hyprctl reload` at startup; our config doesn't load that file. Its Hyprland overview is a workspace grid built from real window positions, so it shows little with parked windows.
- **Noctalia:** it can't resolve its logind session when run as a user service (`NoSessionForPID`), which only affects brightness. Its first-run wizard writes `~/.local/state/noctalia/settings.toml`, with the wallpaper as a store path that goes stale after an upgrade (set it explicitly, task 9.7). Its window switcher (`noctalia msg window-switcher`, `shell.window_switcher.mru`) is an icon-and-title grid of all windows without live previews: usable, not an exposé.

**Launchers (criterion 4).**
- **DMS built-in:** no open-window entries (only through third-party plugins) and no calculator. Fails.
- **Noctalia built-in:** open windows under the `/win` prefix work; `shell.launcher.providers.windows.global` can add them to plain search.
- **Vicinae:** open apps appear in plain search with contextual actions; selecting the app focuses its first window. Every window, with title and workspace, is listed in the "Switch Windows" command (`wm` provider), which Super+Space opens directly through `vicinae deeplink vicinae://launch/wm/switch-windows`. The user's favourite so far.
  - **Required setting:** `launcher_window.layer_shell.keyboard_interactivity = "on_demand"`. With the default `exclusive`, Hyprland refuses to move focus while the panel holds the keyboard. The focus request still warps the pointer toward the parked window, which clamps it to the bottom edge, and the window stays parked. Visible windows only seemed to work because focus-follows-mouse picked them up after the panel closed. `on_demand` fixes it, and the panel still takes typing immediately. If Vicinae wins, this setting must be owned by our config (8.7), not its settings screen.
  - Its first-run wizard asks for a global hotkey, which must not be one of our binds (Ctrl+Space, Super+Space): Hyprland's bind already runs the command, and a second grab would toggle twice. The hotkey and "paste to active window" come from its input server, which reads keyboards from `/dev/input`, including while locked; it can be turned off with `input_server.enabled = false`.
- **Walker + Elephant:** plain search (Ctrl+Space) lists apps only; picking one starts a new instance, launched through uwsm (`app-Hyprland-…scope`). Windows can be added to plain search through Walker's provider settings. `walker --provider windows` (Super+Space) lists every window and raises the selected one correctly, including windows behind others; no extra setting was needed. Elephant logs harmless errors from its Arch package provider (`pacman` missing).

**Noctalia + Vicinae against the checklist:** 0.56 compatibility, guardrails, caffeine (a logind idle inhibitor, which hypridle honours), launcher, bar with volume, Bluetooth, network and tray, notifications with do-not-disturb (popups suppressed, kept in history), config ownership (HM `config.toml`, settings screen in a separate override file, live reload) and theming (no GTK/Qt/terminal files unless templates are enabled; only gsettings `color-scheme`) all pass. Screenshots: region and monitor capture at full resolution to the clipboard and `~/Pictures/Screenshots`; bare-bones, but the built-in annotator (`screenshot-annotate`) is a strong candidate for task 9.1, next to Flameshot 14, Satty and Gradia.

**Open question raised by the tryout:** the stack layout (D5) assumed an exposé would be available, and none fits parked windows. A workspace-per-app model would let workspace-based overviews show every app. To be decided before the window model is final.

### D9: Config ownership: HM and chezmoi, one owner per path

- **HM owns** files that use Nix values (store paths, the shared palette, generated units) or that need build-time checks.
- **chezmoi owns** files edited through a program's settings screen, tweaked live and captured with `chezmoi re-add`.
- **Never both:** a path is never managed by both tools. HM refuses to clobber existing files, and chezmoi would replace HM's symlinks.
- **During the tryout,** shell config is unmanaged (native). After the choice, criterion 8 decides between HM, chezmoi, or layered (HM defaults plus native overrides stored elsewhere), and the decision is written down here.
- **Decision (task 8.7): layered, HM plus native, no chezmoi.**
  - **Noctalia:** HM owns `~/.config/noctalia/config.toml` (guardrails in `shell.nix`, look in `theme.nix`, screenshot directory in `tools.nix`) and the palette in `palettes/NordGold.json`. The settings screen writes to `~/.local/state/noctalia/settings.toml`, which overrides config.toml and can be copied into Nix when a change should stay. Config changes reload live, without restarting Noctalia.
  - **Vicinae:** `~/.config/vicinae/settings.json` stays Vicinae's own, written by its settings screen. It imports the HM-owned `nix.json`, which holds what the desktop relies on (`on_demand`, D8). Values in settings.json take precedence over imports, so these keys must not be set there. Activation warns if settings.json doesn't import `nix.json`.
  - **chezmoi** owns none of these. It manages icons in `~/.local/share/icons/hicolor`, where HM only adds `index.theme`; `chezmoi diff` shows no change there.

### D10: Screenshots, clipboard, automount, terminal

- **Screenshots:** candidates are the chosen shell's built-in tool, and `grim` + `slurp` + `satty`. Print opens region, window or screen selection; the result goes to the clipboard and `~/Pictures/Screenshots`. Tested on both monitors at scale 2.
- **Clipboard history:** cliphist (HM service, Hyprland target), searched through the omnibox. If the chosen launcher has its own clipboard history, that replaces cliphist.
- **Automount:** udiskie (HM service) with its unit bound to the Hyprland target, so it doesn't double-mount next to GNOME's automounting.
- **Terminal:** foot, `programs.foot`. It renders on the CPU, so it stays usable when GL is broken.

### D11: Dev container at login

- **Unit:** an HM systemd user unit, `Type=oneshot`, `RemainAfterExit=yes`, `KillMode=process`, running `/usr/bin/distrobox enter nix -- true`.
  - `KillMode=process` matters: when this unit starts the container, the container's conmon stays in the unit's cgroup. With the default `control-group`, stopping the unit (e.g. a switch restarting it after a change) kills the container and everything in it, including Zed. That happened once during task 8.2, when the unit's command briefly depended on the GPU driver path.
  - It is wanted by `default.target`, so it runs for both sessions.
  - It has a generous `TimeoutStartSec`, because the container's first start runs its init.
- **Effect:** container-launched Emacs and Zed start immediately on first use. There is no Emacs daemon unit.
- **Emacs client:** `emacsclient.desktop` (chezmoi-managed) is retargeted into the container: `distrobox-enter -n nix -- emacsclient -c -a "" %F`. `-a ""` starts an Emacs daemon inside the container on first use, so no service is needed. The socket lives in the shared `/run/user/1000/emacs/`. The change is made in the dotfiles repo and applied with `chezmoi apply`. Like `emacs.desktop`, the entry uses absolute paths and passes `--env GTK_THEME=Adwaita:dark` to the container, so a daemon started from the client gets the same dark GTK theme.
- **chezmoi auto-pushes:** the dotfiles config has `autoCommit` and `autoPush`, so `chezmoi add`/`re-add` commit and push immediately. Check `chezmoi diff` before a bare `chezmoi apply`: the source can lag behind live edits and would overwrite them.
- **Alternatives rejected:**
  - `podman start nix`: returns before distrobox init has finished.
  - A Quadlet: distrobox owns the container's lifecycle and flags.
- **Duplicate launcher entries:** the host-profile desktop entries for Zed and Emacs are removed by installing those packages with `share/applications` filtered out. The binaries stay, since the container launchers use `~/.nix-profile/bin/*`. Container-exported and chezmoi-managed entries remain. Emacs entries that share a desktop-file ID with the chezmoi-managed ones in `~/.local/share/applications` are already masked by them; the filter handles the rest (`dev.zed.Zed.desktop`, other Emacs IDs).

### D12: Autostart apps

- Autostart uses standard XDG autostart, which uwsm runs in Hyprland.
- **Bitwarden:** its existing portal-written entry.
- **Steam:** its existing entry, as is.
- **Synology Drive:** enable its own "start on login" setting from GNOME, so the entry is portal-written like Bitwarden's. If the app doesn't offer that, add an HM-owned `~/.config/autostart` entry that runs the flatpak. **Outcome:** the setting exists, but as a flatpak it only records the choice in `~/.SynologyDrive/data/` and writes no autostart entry, so `session.nix` owns the entry (same command as the flatpak's exported entry).
- **Session differences:** in Hyprland, uwsm runs autostart entries as `app-*@autostart.service` units via `xdg-desktop-autostart.target`. GNOME's session manager launches them itself as `app-gnome-*` / `app-flatpak-*` scopes and never starts those units.
- **Vesktop:** disable its "start on login" setting, or delete the file.
- Flatpaks are kept (no Nix duplicates), so each app has exactly one install and one config.
- **Tray at login:** autostart entries start in the same instant as the shell. Apps that start before the shell owns `org.kde.StatusNotifierWatcher` fall back to other tray protocols and never show up; Bitwarden and Synology Drive did, Steam registers again later. So Noctalia is `Type=dbus` with `BusName=org.kde.StatusNotifierWatcher`, and an `app-@autostart.service.d` drop-in orders autostart units after it. For the same reason, Noctalia is not restarted on config changes (its HM module's `X-Restart-Triggers` are cleared); it reloads its config files itself.
- **Bitwarden on Wayland:** its launcher script picks X11 whenever both display servers exist (a workaround for an old Electron crash), which is blurry at scale 2 and opens menus on the wrong monitor. An HM-owned flatpak override sets `DISPLAY_MODE=WAYLAND`; it runs natively without problems. As a Wayland app it also registers its tray icon again after a shell restart. Its Ctrl+W quits the app even with "close to tray" enabled; closing the window (Super+Q) goes to the tray.
- **Bitwarden unlock with system authentication:** needs the polkit action `com.bitwarden.Bitwarden.unlock`, which the flatpak can't install and which never existed on this host (so it didn't work in GNOME either). polkit 127 also reads `/etc/polkit-1/actions`. The policy is embedded in Bitwarden's `app.asar`; it was extracted and installed once by hand (`sudo install -Dm644 … /etc/polkit-1/actions/com.bitwarden.Bitwarden.policy`, then `sudo systemctl reload polkit`), outside Home Manager like the GPU setup. It could move into the image. Side note for the image: `/etc/polkit-1` is owned by the nonexistent UID 1001 instead of root.
- **IBus:** the image sets `QT_IM_MODULE`, `QT_IM_MODULES` and `XMODIFIERS` to IBus, which doesn't run in Hyprland. Bitwarden under X11 then failed to start the IBus portal each time it opened, and every failed unit became a notification (uwsm's `fumon`). `env-hyprland` unsets them; compose works through xkb. The Steam runtime still probes the portal at every start, regardless of the environment, so a user D-Bus service file (which takes precedence over `/usr/share/dbus-1/services`) starts the portal through a wrapper that turns its failure into a clean exit. The request still fails, but quietly; in GNOME, where IBus runs, the portal works as before.
- **X11 apps at scale 2:** XWayland upscales X11 apps, which blurs them. `xwayland.force_zero_scaling` gives them real pixels, and they scale themselves: `GDK_SCALE=2` in `env-hyprland` for GTK and CEF apps (Steam, which ignores `STEAM_FORCE_DESKTOPUI_SCALING` and `-forcedesktopscaling`), and an HM-owned flatpak override `QT_SCALE_FACTOR=2` for Synology Drive (Qt). With both monitors at scale 2, `GDK_SCALE` changes nothing for Wayland GTK apps.
- **Synology Drive's tray popup** (title `cloud-drive-ui`, from the tray menu) closes when it loses focus, which with focus following the pointer happens on the first mouse move; the same happened in GNOME. A `stay_focused` window rule keeps it open until it's closed with Escape or its own controls. Its notification window still appears at varying positions.

### D13: Look (last phase)

- A single palette defined in Nix (`theme.nix`) feeds Hyprland borders, hyprlock, foot, GTK and the bar, unless the tryout (criterion 9) hands theming to the shell.
- **Theming owner (task 8.7): Nix.** Noctalia's theme templates stay off (its default), so it writes no GTK, Qt or terminal theme files; it only sets gsettings `color-scheme`. Its palette (`NordGold`: Nord with Nord yellow as the one accent, on pure black) is defined in `theme.nix`, which also holds the bar look. Windows have no gaps, borders or rounding; unfocused windows are dimmed slightly instead (`desktop/hypr/look.lua`).
- Includes the cursor theme, fonts, bar placement (one or both monitors) and the optional hot-edge reveal: a Lua timer polls the cursor at the top edge while a non-game window is fullscreen and raises the bar. Games are excluded by content type or class.

## Risks / Trade-offs

- **The uwsm target name differs from `wayland-session@hyprland.desktop.target`.**
  → The first task after login checks `systemctl --user list-units 'wayland-session@*'`, and a single option (`wayland.systemd.target`) is corrected.
- **The layout API can't support per-workspace state or z-order control.**
  → Spike before building. Fallbacks are listed in D5.
- **0.56's Lua dispatch breaks third-party IPC use** (shells, launchers, waybar modules).
  → Tryout criterion 1, with individual tools as the fallback.
- **A shell's lock or polkit can't be disabled**, which would lock you out or register a second agent.
  → Guardrail criterion 2 is pass/fail. hyprlock is always the only locker; `loginctl lock-session` is the only lock path.
- **Out-of-store Lua depends on the repo checkout path** and isn't validated at build time.
  → The path is the flake's fixed location. `hyprctl configerrors` is checked after each change. The Lua can move into the store once stable.
- **Nix GPU drivers go stale.** After a nixpkgs update changes Mesa, `/run/opengl-driver` on the host still points at the old drivers until the setup script runs again.
  → Activation warns with the exact `sudo` command. The container's link is updated by the switch itself.
- **Parked windows are positioned off-screen.** Something that trusts a window's position (a screenshot tool listing windows, a shell's window previews) may show them oddly.
  → Checked during the tryout. Windows keep their size, so nothing re-lays out.
- **Portal-written autostart entries are toggled by the apps themselves,** so they can reappear.
  → Documented in D12. They are managed from the app settings.
- **uwsm's `fumon` fails while no notification daemon runs.** It reports failed units as notifications, and until the shell (D8) provides a notification server, it fails itself.
  → Expected until phase 4. Check `systemctl --user list-units --failed` manually until then.
- **The container start adds time to login.**
  → It's a oneshot that doesn't block the graphical session. Launching Emacs just waits for the same start if it's still running.

## Migration Plan

1. **Phase 1, foundation:** D1 to D4, D11, D12. `home-manager switch` on the host from GNOME, then log into Hyprland and check `hyprctl configerrors`, locking (idle, keybind, suspend), polkit, the keyring and the container. This meets the brief's "done when" list except daily-use comfort.
2. **Phase 2, window model:** D5 to D7 (spike first).
3. **Phase 3, launcher:** as part of the tryout.
4. **Phase 4, shell tryout and tools:** D8 to D10, recorded decision.
5. **Phase 5, look:** D13.

**Rollback:** log into GNOME and run `home-manager switch --rollback` (or activate an earlier generation). Nothing in this change alters the image or GNOME's config. Emergency unlock from a TTY is the `hyprctl --instance 0 eval` command from the brief. After phase 1 is confirmed in daily use, the image's task 8.5 can be finished.

## Open Questions

- The gamescope-nested Steam follow-up: a separate change, created once plain Steam on Hyprland has been observed.
