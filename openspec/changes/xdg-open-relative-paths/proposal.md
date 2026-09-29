## Why

In the Hyprland session, `xdg-open <relative path>` opens the wrong file when the default handler is a flatpak. Opening `Screencast.mp4` from `~/Videos/Screencasts` makes Showtime look for `~/Screencast.mp4`, and it fails with a misleading "Failed to pause". GNOME isn't affected. Found while verifying the fullscreen idle-inhibit rule (hyprland-desktop task 4.5).

Findings:
- On the host, `xdg-utils` 1.2.1 doesn't know `XDG_CURRENT_DESKTOP=Hyprland`, so it uses its generic mode. That mode passes relative paths unchanged to the handler's `Exec` line.
- Flatpak handlers use `--file-forwarding … @@u %U @@`. A relative path isn't a URI, so it isn't forwarded through the document portal. The app resolves it against its own working directory inside the sandbox, which is `$HOME`.
- `gio open` (what `xdg-open` uses under GNOME) makes the path absolute and works in Hyprland too.
- Absolute paths work with `xdg-open` in both sessions.
- The nix container's `/usr/local/bin/xdg-open` is distrobox's shim. It runs the host's `xdg-open` through `host-spawn` and keeps the working directory, so it inherits the host bug rather than causing it.

## What Changes

- Make `xdg-open` in the Hyprland session resolve relative paths before handing them to the default application, both on the host and from the nix container.
- Leave GNOME's behaviour unchanged, and don't replace the image's `xdg-utils`.
- Mechanism (a wrapper that makes paths absolute or delegates to `gio open`, where it sits in `PATH`, and how the container shim reaches it) is decided in design.md.

## Capabilities

### New Capabilities
- `file-opening`: `xdg-open` opens files, including relative paths, in the default application (native or flatpak) from the Hyprland session and from the nix container.

### Modified Capabilities
<!-- None: no existing specs in openspec/specs/. -->

## Impact

- Home Manager config, likely `desktop/tools.nix`. It may add a wrapper script and a `PATH` or environment adjustment scoped to the Hyprland session.
- `~/.nix-profile` is shared between the host and the nix container, so anything installed there must behave correctly in both.
- Other launchers that go through `xdg-open` (terminal, launcher candidates from hyprland-desktop group 8) benefit.
- Depends on hyprland-desktop only for the session scoping (`~/.config/uwsm/env-hyprland`, the Hyprland target).
