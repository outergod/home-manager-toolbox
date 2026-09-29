{ config, lib, pkgs, ... }:

let
  # uwsm's session target for hyprland-uwsm.desktop. GNOME never reaches it,
  # so everything bound here stays out of the fallback session (D3).
  target = "wayland-session@hyprland.desktop.target";

  # Enables an image-provided unit for the Hyprland session only. The image
  # unit stays the source of truth.
  #
  # The drop-in orders the unit after the target explicitly. Otherwise the
  # target is implicitly ordered after the units it wants, which, with the
  # image units' After=graphical-session.target and uwsm's
  # Before=graphical-session.target, is a cycle that breaks `uwsm stop`.
  wantImageUnit = unit: {
    "systemd/user/${target}.wants/${unit}".source =
      config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/${unit}";
    "systemd/user/${unit}.d/session.conf".text = ''
      [Unit]
      After=${target}
      PartOf=${target}
    '';
  };
in
{
  # HM binds its desktop services (hypridle, shells, launchers, ...) to this.
  wayland.systemd.target = target;

  xdg.configFile = lib.mkMerge [
    (wantImageUnit "hyprpolkitagent.service")
    (wantImageUnit "hypridle.service")
    {
      # Sourced by uwsm's environment preloader for the Hyprland session only.
      # Cursor matches GNOME's until the look phase picks one (D13).
      "uwsm/env-hyprland".text = ''
        export XCURSOR_THEME=Adwaita
        export XCURSOR_SIZE=24
      '';
    }
  ];
}
