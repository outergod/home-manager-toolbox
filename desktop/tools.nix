{ config, lib, pkgs, ... }:

let
  # xdg-utils runs in generic mode under Hyprland and passes relative paths to
  # the handler unchanged, so flatpak apps resolve them against $HOME. Make
  # them absolute, then hand off to the next xdg-open on PATH: the image's on
  # the host, the distrobox shim in the container. No runtimeInputs, so the
  # image's xdg-open keeps its own PATH. See
  # openspec/changes/xdg-open-relative-paths/design.md (D1, D3, D4).
  xdg-open = pkgs.writeShellScriptBin "xdg-open" ''
    if [ "$#" -eq 1 ]; then
      case $1 in
        "" | /* | -*) ;;
        *)
          # Same scheme test as xdg-utils, so both agree on what is a path.
          if ! [[ $1 =~ ^[[:alpha:]][[:alnum:]+.-]*: ]]; then
            dir=$(pwd -P) || exit 1
            set -- "''${dir%/}/$1"
          fi
          ;;
      esac
    fi

    IFS=: read -ra dirs <<<"$PATH"
    for dir in "''${dirs[@]}"; do
      candidate=''${dir:-.}/xdg-open
      if [ -f "$candidate" ] && [ -x "$candidate" ] && ! [ "$candidate" -ef "$0" ]; then
        exec "$candidate" "$@"
      fi
    done

    echo "xdg-open: no other xdg-open found on PATH" >&2
    exit 1
  '';
in
{
  # Fallback terminal. It renders on the CPU, so it keeps working when GL is
  # broken.
  programs.foot.enable = true;

  home.packages = [ xdg-open ];
}
