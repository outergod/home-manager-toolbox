Note: run `home-manager switch` on the host only (host terminal or `distrobox-host-exec home-manager switch`). Keep GNOME as the fallback session; roll back with `home-manager switch --rollback` from GNOME if Hyprland breaks.

## 1. Repository structure

- [x] 1.1 Create `desktop/default.nix` importing empty modules `hyprland.nix`, `session.nix`, `lock.nix`, `shell.nix`, `tools.nix`, `container.nix`, `theme.nix`, import it from `home.nix`, and verify `nix build .#homeConfigurations.outergod.activationPackage` succeeds
- [x] 1.2 Create `desktop/hypr/` with a `desktop.lua` entry module and verify it is tracked by git (flake sources only see tracked files)

## 2. Phase 1: Hyprland base config

- [x] 2.1 Configure `wayland.windowManager.hyprland` with `configType = "lua"`, `package = null`, `portalPackage = null`, `systemd.enable = false`, and a generated entry that requires `desktop`; verify `~/.config/hypr/hyprland.lua` is generated after switch
- [x] 2.2 Link `desktop/hypr/*.lua` into `~/.config/hypr/` via `mkOutOfStoreSymlink` and add the generated `nix.lua` data module (store paths); verify the links resolve into the repo working tree
- [x] 2.3 Write `~/.config/hypr/.luarc.json` pointing at `/usr/share/hypr/stubs`; verify Zed/Emacs Lua LSP resolves `hl.*` without diagnostics
- [x] 2.4 Add an `onChange` hook running `/usr/bin/hyprctl reload` when a Hyprland instance exists; verify switch succeeds both with and without a running Hyprland
- [x] 2.5 Minimal Lua base: both monitors by `desc:` at scale 2 (left/right per GNOME's layout), `misc.allow_session_lock_restore = true`, `misc.force_default_wallpaper = 0`, Super+Q close, foot on a temporary Super+Return; verify after login that `hyprctl configerrors` is empty and `hyprctl monitors` shows the expected positions
- [x] 2.6 Add foot via `programs.foot` (no nixGL wrap) and verify it opens in Hyprland

## 3. Phase 1: Session scoping

- [x] 3.1 In a Hyprland session, run `systemctl --user list-units 'wayland-session@*'` and confirm the target name; record it in design.md D3 if it differs from `wayland-session@hyprland.desktop.target`
- [x] 3.2 Set `wayland.systemd.target` to the confirmed target; verify with `grep -r graphical-session.target ~/.config/systemd/user/` that no HM-generated desktop unit is wanted by `graphical-session.target`
- [x] 3.3 Link the image's `hyprpolkitagent.service` into the target's `.wants/` via out-of-store symlink; verify `systemctl --user status hyprpolkitagent` is active in Hyprland and inactive in GNOME, and that `pkexec true` shows a prompt in Hyprland
- [x] 3.4 Write `~/.config/uwsm/env-hyprland` (initially empty or cursor vars); verify uwsm picks it up (`systemctl --user show-environment` in Hyprland)
- [x] 3.5 Verify the keyring needs no prompt in Hyprland (e.g. open an app using the secret service after login)

## 4. Phase 1: Lock and idle

- [x] 4.1 Configure `services.hypridle` with `package = null`: lock_cmd, before_sleep_cmd, `inhibit_sleep = 3`, after_sleep DPMS on (0.56 dispatch syntax), listeners at 900 s (`loginctl lock-session`) and 1200 s (DPMS off/on); verify `~/.config/hypr/hypridle.conf` content
- [x] 4.2 Link the image's `hypridle.service` into the Hyprland target's `.wants/`; verify it runs in Hyprland only
- [x] 4.3 Configure `programs.hyprlock` with `package = null` and an input field with `fade_on_empty = false`; verify `/usr/bin/hyprlock` shows the field and unlocks with the password
- [x] 4.4 Bind Super+L to `loginctl lock-session`; verify the keybind locks
- [x] 4.5 Add the window rule inhibiting idle for fullscreen windows; verify a fullscreen video survives a temporarily shortened idle timeout
- [x] 4.6 Verify idle lock with a temporarily shortened timeout, then restore 900/1200 s
- [x] 4.7 Verify suspend: `systemctl suspend`, resume, and confirm the first frame shown is the lock screen
- [x] 4.8 Verify lock over plain Steam (Big Picture fullscreen) covers both monitors
- [x] 4.9 Verify crash recovery once: kill hyprlock while locked, restore from TTY with `hyprctl --instance 0 eval 'hl.dispatch(hl.dsp.exec_cmd("/usr/bin/hyprlock"))'`, unlock

## 5. Phase 1: Dev container and autostart

- [ ] 5.1 Add the `distrobox-nix` oneshot user unit (`/usr/bin/distrobox enter nix -- true`, `RemainAfterExit`, generous `TimeoutStartSec`, `WantedBy=default.target`); after a reboot, verify Emacs and Zed start from their launchers without entering the container first, in both GNOME and Hyprland
- [x] 5.2 Remove host-profile desktop entries for Zed and Emacs by filtering `share/applications` out of those packages; verify only one Zed and one Emacs entry exist (`ls ~/.nix-profile/share/applications`, GNOME overview)
- [x] 5.3 In the dotfiles repo, retarget `emacsclient.desktop` to `distrobox-enter -n nix -- emacsclient -c -a "" %F`, commit, `chezmoi apply`; verify the first launch starts a daemon in the container and the second reuses it
- [x] 5.4 Remove Vesktop's autostart (disable "start on login" in Vesktop, or delete `~/.config/autostart/dev.vencord.Vesktop.desktop`); verify it doesn't start at the next login
- [ ] 5.5 Enable Synology Drive's start-on-login from GNOME (fallback: HM-owned autostart entry running the flatpak); verify Bitwarden, Synology Drive and Steam start in Hyprland at login
- [ ] 5.6 Phase 1 gate: `hyprctl configerrors` empty, all lock paths verified, polkit and keyring verified; report readiness for image task 8.5

## 6. Phase 2: Window model

- [ ] 6.1 Spike: register a minimal Lua layout via `hl.layout.register` and confirm (a) the provider can identify the workspace being recalculated, (b) `bring_to_top` controls z-order of overlapping tiled windows, (c) `layout_msg` is reachable from a keybind; record findings in design.md D5 and pick stack layout or fallback
- [ ] 6.2 Workspaces: persistent workspace 1 on the left monitor and 2 on the right, no workspace binds; verify new windows open on the monitor under the pointer and no other workspaces appear
- [ ] 6.3 Implement stack mode (full area, front = most recent focus); verify with three windows that opening and focusing behave per spec
- [ ] 6.4 Implement split mode (Super+Left/Right with MRU partner, Super+Up back to stack, auto-exit when a partner leaves); verify all window-management split scenarios
- [ ] 6.5 Dialog rules: float modal/transient windows, portal file pickers, polkit and pinentry, and suppress maximize; verify a GTK file chooser, a Qt dialog and a polkit prompt float at natural size
- [ ] 6.6 Super+Shift+Left/Right move to monitor; verify the window arrives in front and keeps focus
- [ ] 6.7 Focus: `follow_mouse = 1`, warps on programmatic focus, Alt+Tab to previous window; verify raising a window on the other monitor moves pointer and focus, not the window
- [ ] 6.8 Super+F true fullscreen toggle; honour app fullscreen requests; verify the bar is hidden in true fullscreen and visible otherwise
- [ ] 6.9 Mouse binds (Super+LMB/RMB) and media/volume keys with `locked = true`; verify volume keys work while locked

## 7. Phase 2: Keyboard

- [ ] 7.1 Input: `kb_layout = "us,us"`, `kb_variant = ",dvorak"`, `compose:menu`; Super+Tab cycles the layout; verify on a regular keyboard
- [ ] 7.2 Look up the Kyria's name with `hyprctl devices` and add a device block pinning it to plain `us`; verify toggling doesn't affect the Kyria

## 8. Phase 3/4: Shell and launcher tryout

- [ ] 8.1 Add `desktop.shell` and `desktop.launcher` options in `shell.nix` with shared guardrails (units on the Hyprland target, nixGL wrap), and bind Super+Space to the selected launcher; verify switching `none` ↔ a candidate installs/starts only that candidate
- [ ] 8.2 DMS candidate: nixpkgs package, own unit, lock/polkit/idle disabled, lock action → `loginctl lock-session`, nixGL reaching `qs`; verify guardrails (`busctl --user` shows no second polkit agent, lock button shows hyprlock)
- [ ] 8.3 Noctalia 5 candidate: HM module, lock/polkit/idle disabled, lock action → `loginctl lock-session`, nixGL wrap; verify guardrails
- [ ] 8.4 Vicinae and Walker (+ Elephant) launcher candidates via HM modules, bound to the Hyprland target; verify each opens on Super+Space
- [ ] 8.5 Evaluate each shell × launcher combination against the D8 checklist (0.56 compatibility, guardrails, caffeine vs hypridle, launcher spec, bar, notifications/DND, screenshots, config ownership, theming); record results in a "Tryout results" section in design.md
- [ ] 8.6 Decide shell and launcher with the user, set the options, remove unused candidates; record the decision in design.md
- [ ] 8.7 Decide ownership of the chosen shell's config (HM, chezmoi, or layered) and of theming; record in design.md D9/D13 and set up accordingly; verify `home-manager switch` and `chezmoi apply` don't conflict

## 9. Phase 4: Tools

- [ ] 9.1 Screenshot UI on Print (shell built-in or grim + slurp + satty); verify region, window and monitor captures on both monitors at correct resolution, to clipboard and `~/Pictures/Screenshots`
- [ ] 9.2 Clipboard history (launcher built-in or cliphist on the Hyprland target), reachable by prefix in the omnibox; verify recalling an earlier copy
- [ ] 9.3 udiskie on the Hyprland target; verify a USB stick mounts in Hyprland and udiskie doesn't run in GNOME
- [ ] 9.4 Omnibox sources: calculator, files, power actions (lock via `loginctl lock-session`); verify each launcher scenario in specs/launcher
- [ ] 9.5 Caffeine toggle in the bar; verify idle lock is inhibited while enabled (shortened timeout test)
- [ ] 9.6 Bar contents: clock, tray, volume, Bluetooth, network; verify tray icons of Bitwarden, Synology Drive and Steam work
- [ ] 9.7 Wallpaper on both monitors; verify after re-login

## 10. Phase 5: Look

- [ ] 10.1 Define the palette, fonts and cursor in `theme.nix` (or hand theming to the shell per 8.7); verify GTK/Qt apps are dark with the chosen cursor
- [ ] 10.2 Apply the palette to Hyprland borders, hyprlock, foot and the bar/shell; verify the lock screen matches the desktop
- [ ] 10.3 Decide bar placement (one or both monitors) with the user and configure it; verify
- [ ] 10.4 Optional: hot-edge bar reveal over fullscreen non-game windows; verify with a fullscreen video and that games are excluded

## 11. Wrap-up

- [ ] 11.1 Daily-use check with the user; collect adjustments and apply them
- [ ] 11.2 Final verification: `hyprctl configerrors` empty, `openspec validate hyprland-desktop --strict` passes, design.md reflects the final decisions
- [ ] 11.3 Open the gamescope-nested Steam follow-up change (gs.sh, lock over nested gamescope)
