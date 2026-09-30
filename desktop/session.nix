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
  # Bitwarden's launcher picks X11 when both display servers are available,
  # which is blurry at scale 2 and misplaces menus. Wayland works fine. Owned
  # here, so `flatpak override --user com.bitwarden.desktop` would conflict.
  xdg.dataFile."flatpak/overrides/com.bitwarden.desktop".text = ''
    [Environment]
    DISPLAY_MODE=WAYLAND
  '';

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

      # Synology Drive's own start-on-login setting writes no autostart entry
      # when run as a flatpak (D12). Same command as its exported entry.
      "autostart/com.synology.SynologyDrive.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Synology Drive Client
        Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=synology-drive com.synology.SynologyDrive start
        Icon=com.synology.SynologyDrive
        X-Flatpak=com.synology.SynologyDrive
      '';
    }
  ];
}
