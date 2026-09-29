## Why

The bazzite-hyprland image boots into a uwsm-managed Hyprland 0.56 session, but this Home Manager flake has no Hyprland configuration yet. The old NixOS-era config is written for a pre-Lua Hyprland, uses a workspace-centric tiling model that never matched how I work, and ignores the image's hard rules (image-provided locker/polkit/idle, session scoping next to GNOME). Until the desktop is usable daily, task 8.5 of the image change (suspend check, deleting `~/.local/share/nix`) stays blocked.

The target workflow comes from GNOME: few windows, each normally filling its monitor, two 4K monitors side by side, and a keyboard-driven omnibox to find or start anything instead of hunting through workspaces.

## What Changes

- Configure Hyprland 0.56 from Home Manager in Lua (`configType = "lua"`, `package = null`, `portalPackage = null`), with larger logic in real `.lua` modules via `extraLuaFiles`, plus a `.luarc.json` pointing at the image's `/usr/share/hypr/stubs`.
- Scope every Hyprland-only service to uwsm's `wayland-session@hyprland.desktop.target` (via `wayland.systemd.target` and links to image-provided units) so GNOME, the fallback session, is unaffected.
- Use the image's hyprlock, hypridle and hyprpolkitagent; configure hypridle and hyprlock only. Lock on idle, on Super+L and before suspend, all through `loginctl lock-session`. Provide automatic (fullscreen) and manual ("caffeine") idle inhibition.
- Replace workspaces with one fixed workspace per monitor (HDMI-A-1 left/primary, DP-2 right, both scale 2) and a custom Lua layout: each monitor is a stack where the focused window fills the screen; Super+Left/Right tiles it in halves with the previously used window, Super+Up returns to the full stack; Super+Shift+Left/Right moves a window to the other monitor. Dialogs always float and are never maximized. Bar stays visible except for true fullscreen.
- Add a type-to-find omnibox on Super+Space: one entry per open window plus apps, with prefixes for other sources (calculator, clipboard history, files, power actions). Raising a window never moves it; focus and cursor go to it.
- Keybindings: Super+Q close, Super+L lock, Super+Tab toggles US/Dvorak on all keyboards except the Kyria rev3 (hardware Dvorak, always `us`), Alt+Tab to previous window.
- Run a structured tryout of DankMaterialShell and Noctalia 5 (bar, notifications, OSD, tray, volume/Bluetooth/network, wallpaper, screenshots) combined with the launcher candidates (shell built-in, Vicinae, Walker), against a fixed checklist, then commit to one combination. The shells' own lock screen, polkit agent and idle management stay disabled.
- Decide per chosen shell how its configuration is owned: Home Manager, native settings UI versioned with chezmoi (`chezmoi re-add`), or layered (HM defaults plus runtime overrides). Decide who owns theming (shell or Nix).
- Add a screenshot flow with a GNOME-like UI, clipboard history, and USB automount scoped to Hyprland.
- Add foot as the Nix fallback terminal (no GPU/nixGL dependency).
- Start the `nix` distrobox container at login in the systemd user session (both sessions), so container-hosted Emacs and Zed work on first launch after boot. No Emacs daemon service.
- Keep Bitwarden and Synology Drive as flatpaks, autostarted in Hyprland; keep Steam's existing autostart; remove Vesktop's autostart entry.
- Keep only the container-launched Emacs and Zed desktop entries; remove the host-profile duplicates.
- Iterate on the look last: palette, fonts, cursor, hyprlock theme matching the shell, bar on one or both monitors, optional hot-edge bar reveal over fullscreen (not for games).

## Capabilities

### New Capabilities
- `hyprland-session`: Lua config generation, uwsm session integration, scoping to the Hyprland target, image-vs-Nix component boundaries, autostart, clean `hyprctl configerrors`.
- `session-lock`: idle, keybind and before-suspend locking with the image's hyprlock/hypridle, crash recovery, idle inhibition (automatic and manual), polkit agent.
- `window-management`: per-monitor stack layout with opt-in half splits, floating dialogs, fixed monitor workspaces, focus behaviour, window keybindings, fullscreen modes.
- `keyboard-input`: US default with switchable Dvorak, per-device exception for the Kyria rev3.
- `launcher`: omnibox for windows, apps and prefixed sources, raise-without-move semantics.
- `desktop-shell`: bar, notifications, OSD, tray, system controls, wallpaper, screenshots, clipboard history, automount; shell tryout and configuration ownership.
- `dev-container`: `nix` distrobox started at login, container-launched Emacs/Zed as the only entries.
- `desktop-theme`: coherent look across shell, hyprlock, terminal, GTK and Hyprland; theming ownership.

### Modified Capabilities
<!-- None: no existing specs in openspec/specs/. -->

## Impact

- `home.nix` grows substantially; likely split into modules (e.g. `hyprland/`, `shell/`). `flake.nix` may gain an input if DankMaterialShell's HM module is used.
- New generated files: `~/.config/hypr/*.lua`, `hypridle.conf`, `hyprlock.conf`, `~/.config/uwsm/env-hyprland`, shell/launcher configs, systemd user units and target wants under `~/.config/systemd/user/`.
- New Nix packages (GPU apps nixGL-wrapped): chosen shell, launcher, foot, screenshot tooling, cliphist, udiskie, fonts/themes.
- chezmoi (`outergod/dotfiles`) is the second config tool, for writable, UI-edited files. Every config path has exactly one owner, HM or chezmoi, never both.
- Cleanup outside HM: Vesktop's entry in `~/.config/autostart`, and duplicate desktop entries. `~/.local/share/applications/emacs.desktop` and `emacsclient.desktop` are chezmoi-managed; changes to them go through the dotfiles repo.
- No Nix-built password-checking binaries; nothing from Nix replaces image-provided hyprland, hyprlock, hypridle, xdph, uwsm or hyprpolkitagent.
- Depends on the bazzite-hyprland image; unblocks its task 8.5.
- Out of scope, follow-up: gamescope-nested Steam (`gs.sh`) and verifying the lock screen over it. Also out of scope: shells' own lock screens (would require shipping the shell in the image), night light.
