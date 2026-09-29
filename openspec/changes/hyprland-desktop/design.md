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
- `wayland.systemd.target` (default `graphical-session.target`) is the target that walker, elephant, noctalia, vicinae, hypridle and other modules bind their units to.
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
  - **Stack mode (default):** every tiled target gets the full `ctx.area`, and the most recently focused window is raised to the top (`bring_to_top`). The area excludes the bar's reserved zone, so the bar stays visible.
  - **Split mode:** entered per workspace through `layout_msg`. The focused window takes the requested half; the most recently used other window on that workspace (lowest `focus_history_id`) takes the other half. The rest stay stacked behind.
  - **Leaving split mode:** Super+Up returns to stack mode. The mode also ends when either split window closes or leaves the monitor.
  - **State:** kept in Lua per workspace ID, updated from `hl.on` window events.
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

### D6: Keybindings

| Keys | Action |
|---|---|
| Super+Space | omnibox |
| Super+Q | close window |
| Super+L | lock (`loginctl lock-session`) |
| Super+Left / Right | split: focused window to the left / right half |
| Super+Up | back to full stack |
| Super+Shift+Left / Right | move window to the other monitor |
| Super+F | toggle true fullscreen |
| Super+Tab | toggle US / Dvorak (not on the Kyria) |
| Alt+Tab | previous window |
| Print | screenshot UI |
| Super+LMB / RMB drag | move / resize floating windows |
| Media and volume keys | work while locked (`locked = true`) |

Old workspace, special-workspace and pseudo-tiling binds are dropped.

### D7: Keyboard layouts

- Global input: `kb_layout = "us,us"`, `kb_variant = ",dvorak"`, `compose:menu` carried over. Super+Tab cycles the layout on all keyboards.
- A device block for the Kyria rev3 pins it to plain `us`. The exact device name is confirmed with `hyprctl devices` during implementation (old config: `splitkb.com-kyria-rev3`).

### D8: Shell and launcher tryout

- **Selection:** a local option in `shell.nix`, `desktop.shell = "dms" | "noctalia" | "none"` and `desktop.launcher = "builtin" | "vicinae" | "walker"`. Only the selected combination is installed and started (bound to the Hyprland target). Switching is a one-line edit plus a switch, and rollback is a generation rollback.
- **Packaging:** DMS starts from the nixpkgs package with our own unit, so no new flake input is needed. DMS's flake and its HM module are adopted only if DMS wins and the module adds value.
- **nixGL:** DMS, Noctalia and Vicinae render with GL and are wrapped with `config.lib.nixGL.wrap`. For DMS, the wrap must also reach the `qs` process it spawns.
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

### D9: Config ownership: HM and chezmoi, one owner per path

- **HM owns** files that use Nix values (store paths, the shared palette, generated units) or that need build-time checks.
- **chezmoi owns** files edited through a program's settings screen, tweaked live and captured with `chezmoi re-add`.
- **Never both:** a path is never managed by both tools. HM refuses to clobber existing files, and chezmoi would replace HM's symlinks.
- **During the tryout,** shell config is unmanaged (native). After the choice, criterion 8 decides between HM, chezmoi, or layered (HM defaults plus native overrides stored elsewhere), and the decision is written down here.

### D10: Screenshots, clipboard, automount, terminal

- **Screenshots:** candidates are the chosen shell's built-in tool, and `grim` + `slurp` + `satty`. Print opens region, window or screen selection; the result goes to the clipboard and `~/Pictures/Screenshots`. Tested on both monitors at scale 2.
- **Clipboard history:** cliphist (HM service, Hyprland target), searched through the omnibox. If the chosen launcher has its own clipboard history, that replaces cliphist.
- **Automount:** udiskie (HM service) with its unit bound to the Hyprland target, so it doesn't double-mount next to GNOME's automounting.
- **Terminal:** foot, `programs.foot`, not nixGL-wrapped. It renders on the CPU, so it stays usable when GL is broken.

### D11: Dev container at login

- **Unit:** an HM systemd user unit, `Type=oneshot`, `RemainAfterExit=yes`, running `/usr/bin/distrobox enter nix -- true`.
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

### D13: Look (last phase)

- A single palette defined in Nix (`theme.nix`) feeds Hyprland borders, hyprlock, foot, GTK and the bar, unless the tryout (criterion 9) hands theming to the shell.
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
- **nixGL doesn't reach child processes** (DMS spawning `qs`).
  → Verify at tryout, and wrap the child explicitly if needed.
- **Overlapping stacked windows still render underneath** (small GPU cost; translucent windows show through).
  → Acceptable. The fallback layouts avoid it if it's noticeable.
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
