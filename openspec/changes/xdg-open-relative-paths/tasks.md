Note: run `home-manager switch` on the host only (host terminal or `distrobox-host-exec home-manager switch`). Roll back with `home-manager switch --rollback`; `/usr/bin/xdg-open` keeps working if called directly.

## 1. Wrapper

- [ ] 1.1 Add the `xdg-open` wrapper to `desktop/tools.nix` as a `writeShellScriptBin` without `runtimeInputs` (design D1, D3, D4): absolutize a single argument that doesn't start with `/` or `-` and has no URL scheme using `pwd -P`, then exec the first `xdg-open` on `PATH` that isn't `-ef` itself, failing with an error if there is none; verify `nix build .#homeConfigurations.outergod.activationPackage` succeeds and `shellcheck` reports nothing on the built script
- [ ] 1.2 Test the built script against a stub `xdg-open` placed after it on `PATH` that prints its arguments; verify `a.mp4`, `./sub/a.mp4`, `../a.mp4` and `'Clip #1 (50%).mp4'` become `$(pwd -P)/…`, and that `/abs/a.mp4`, `file:///abs/a.mp4`, `https://example.org`, `mailto:x@example.org` and `--version` pass through unchanged
- [ ] 1.3 Verify the self-skip: with the profile directory listed several times on `PATH` and no other `xdg-open`, the wrapper exits non-zero with an error instead of looping
- [ ] 1.4 Switch on the host; verify `command -v xdg-open` resolves to `~/.nix-profile/bin/xdg-open` in a Hyprland terminal, via `host-spawn --no-pty sh -c 'command -v xdg-open'`, and in the container, and that `rpm -V xdg-utils` (host) reports no changes

## 2. Behaviour in Hyprland

- [ ] 2.1 On the host, in `~/Videos/Screencasts`, run `xdg-open Screencast.mp4` with Showtime (flatpak) as default; verify the video plays
- [ ] 2.2 On the host, open a relative path whose default handler is native (check with `xdg-mime query default <type>`) from a directory other than `$HOME`; verify the right file opens
- [ ] 2.3 Inside the `nix` container, repeat 2.1 from `~/Videos/Screencasts`; verify the video plays on the host
- [ ] 2.4 With `~/foo.txt` present, run `xdg-open foo.txt` in a directory without `foo.txt`, on the host and in the container; verify nothing opens and the exit status is non-zero
- [ ] 2.5 Open a file named with spaces, `#` and `%` by relative path; verify the handler opens that file
- [ ] 2.6 Run `xdg-open` with an absolute path and with `https://example.org`; verify they open in the default handler and browser as before

## 3. GNOME fallback

- [ ] 3.1 Log into GNOME and run `xdg-open` with a relative path from a directory other than `$HOME`; verify the file opens in the default application
