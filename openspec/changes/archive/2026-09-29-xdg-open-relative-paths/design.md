## Context

See proposal.md (Why) for the bug and its cause. Facts that shape the fix:

- The host's `/usr/bin/xdg-open` (xdg-utils 1.2.1) sends an argument to `open_generic` when `XDG_CURRENT_DESKTOP` isn't a desktop it knows. There, an argument counts as a file if it starts with `file://` or has no URL scheme (`is_file_url_or_path`). The argument is passed to the handler's `Exec` line unchanged. Absolute paths reach flatpak's `--file-forwarding` correctly. Relative ones don't.
- `PATH` puts `~/.nix-profile/bin` first everywhere that matters:
  - in the host's `systemd --user` environment, which Hyprland-launched apps and `host-spawn`'d commands inherit (`/home/outergod/.nix-profile/bin:…:/usr/local/bin:/usr/bin:…`);
  - in the `nix` container, where it comes before `/usr/local/bin`.
- In the container, `/usr/local/bin/xdg-open` is a symlink to `distrobox-host-exec`. That runs `host-spawn --no-pty xdg-open "$@"`, which keeps the working directory, and the host then resolves `xdg-open` through the host `PATH` above.
- `~/.nix-profile` is the same profile on the host and in the container, so one wrapper installed there is found first in both places.

## Goals / Non-Goals

**Goals:**
- Fix the problem where it starts (a relative path reaching the handler) with one small wrapper that works the same on the host and in the container.
- Keep the image's `xdg-open` in charge of choosing and launching the handler.

**Non-Goals:**
- Opening files that exist only inside the container's filesystem (for example the container's `/usr` or `/etc`) with host applications. The path is resolved correctly but doesn't exist on the host, so `xdg-open` fails there as it already does.
- Fixing programs that call `/usr/bin/xdg-open` by absolute path, or that open files through the portal's OpenURI API. These pass absolute paths or URIs in practice.
- Changing which application handles which type (`mimeapps.list`).

## Decisions

### D1: Make relative paths absolute, then hand off to the real `xdg-open`
The wrapper looks at its single argument. If it doesn't start with `/` or `-` and has no URL scheme, it prepends the physical working directory (`pwd -P`). It then passes the result to the real `xdg-open`, and every other argument goes through untouched. The scheme test uses the same pattern as xdg-utils (`^[[:alpha:]][[:alnum:]+.-]*:`), so the wrapper and xdg-open agree on what is a path. The path is never URI-encoded: xdg-open and flatpak accept absolute paths directly, so names with `#`, `%` or `?` go through byte for byte.

A missing file needs no special handling. The absolute path goes to xdg-open, whose `check_input_file` exits with status 2 ("does not exist"), so a file with the same name elsewhere is never opened.

*Alternatives:*
- **Delegate to `gio open`.** Rejected because it swaps the whole opener for a different one. URI handling, `$BROWSER` fallback, exit codes and handler launching would all change for every argument, not only relative paths, and inside the container `gio` would need forwarding of its own.
- **Convert to `file://` URIs.** Rejected because it needs correct percent-encoding for no benefit, since absolute paths already work.

### D2: Install it in `~/.nix-profile/bin` for every session, not only Hyprland
The wrapper is a Home Manager package named `xdg-open`, defined in `desktop/tools.nix`. Because the profile comes first in both `PATH`s, the same file covers the host, the container, and programs launched from the Hyprland session.

It is not limited to Hyprland. The proposal suggested a Hyprland-only `PATH` entry through `uwsm/env-hyprland`. That wouldn't reach container calls, because the container's `PATH` doesn't include it, and on the host it would depend on when uwsm imports its environment into the user manager compared with the already-running session helper that `host-spawn` talks to. Checking `XDG_CURRENT_DESKTOP` inside the wrapper was rejected too, because it would repeat xdg-utils' own desktop detection. GNOME is only a fallback on this image, so it just has to keep working, and it does: `gio open` opens an absolute path the same way it opens the relative one. The image's xdg-utils stays untouched.

### D3: Find the real `xdg-open` by skipping itself on `PATH`
The wrapper execs the first `xdg-open` on `PATH` that is not the same file as itself (`[ "$candidate" -ef "$0" ]`). That gives the right target in both places without any container detection:
- In the container it finds `/usr/local/bin/xdg-open`, the distrobox shim. The shim calls the host, where the wrapper runs again and finds nothing to change, then finds `/usr/bin/xdg-open`.
- On the host it finds `/usr/bin/xdg-open`.

*Alternative:* hardcode `/usr/local/bin/xdg-open` if `/run/.containerenv` exists, else `/usr/bin/xdg-open`. Rejected because it duplicates distrobox's layout and breaks if the shim moves.

### D4: Use only shell built-ins, and don't change `PATH`
The wrapper is a plain `writeShellScriptBin` without `runtimeInputs`. Adding Nix packages to `PATH` would pass them on to the image's xdg-open and its helpers (`xdg-mime`, `grep`, `sed`), changing which tools those scripts run. `pwd -P`, `case` and `[ -ef ]` are all bash built-ins.

## Risks / Trade-offs

- [The wrapper breaks, and with it every `xdg-open` call in both sessions] → It is a few lines with no dependencies. Recovering from GNOME (log in, roll back from a terminal) doesn't need `xdg-open`. `/usr/bin/xdg-open` still works when called directly, and `home-manager switch --rollback` (or removing the package) restores the previous behaviour.
- [It finds only itself on `PATH` and loops or fails] → The `-ef` self-skip handles the profile appearing several times on `PATH`. If no other `xdg-open` is found, the wrapper exits with an error instead of recursing.
- [The physical `pwd -P` differs from the shell's logical `$PWD` when the directory path includes a symlink] → The kernel resolves the resulting path the same way the caller's own `open()` would. Displayed paths may show `/var/home/…` on the host, which is cosmetic.
- [An argument like `foo:bar.txt` (a relative file whose name contains a colon) is treated as a URL] → That is what xdg-utils does too, so behaviour for such names doesn't change. `./foo:bar.txt` works.
- [A future xdg-utils may learn Hyprland or fix generic mode] → The wrapper then has no effect, because absolute paths are what xdg-open wants anyway, and it can be removed.

## Migration Plan

`home-manager switch` installs the wrapper and it applies to the next `xdg-open` call. No re-login is needed, because `PATH` already includes the profile. To roll back, run `home-manager switch --rollback` or remove the package from `desktop/tools.nix`.
