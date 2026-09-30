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

  # Synology Drive is an X11 Qt app, and XWayland doesn't scale X11 apps
  # (hypr/general.lua), so Qt does.
  xdg.dataFile."flatpak/overrides/com.synology.SynologyDrive".text = ''
    [Environment]
    QT_SCALE_FACTOR=2
  '';

  # The Steam runtime probes the IBus portal at every start. IBus doesn't run
  # in Hyprland, so the portal exits with an error, and the failed unit shows
  # up as a notification. The request still fails, just quietly. In GNOME,
  # where IBus runs, the portal works as before. User service files take
  # precedence over /usr/share/dbus-1/services.
  xdg.dataFile."dbus-1/services/org.freedesktop.portal.IBus.service".text =
    let
      portal = pkgs.writeShellScript "ibus-portal" ''
        /usr/libexec/ibus-portal "$@" || exit 0
      '';
    in
    ''
      [D-BUS Service]
      Name=org.freedesktop.portal.IBus
      Exec=${portal}
    '';

  # HM binds its desktop services (hypridle, shells, launchers, ...) to this.
  wayland.systemd.target = target;

  xdg.configFile = lib.mkMerge [
    (wantImageUnit "hyprpolkitagent.service")
    (wantImageUnit "hypridle.service")
    {
      # Sourced by uwsm's environment preloader for the Hyprland session only.
      # The cursor is the desktop's (theme.nix).
      "uwsm/env-hyprland".text = ''
        export XCURSOR_THEME=${config.desktop.theme.cursor.name}
        export XCURSOR_SIZE=${toString config.desktop.theme.cursor.size}

        # XWayland doesn't scale X11 apps (hypr/general.lua), so X11 GTK and
        # CEF apps such as Steam scale themselves. Both monitors are at
        # scale 2, so Wayland GTK apps are unaffected.
        export GDK_SCALE=2

        # The image points apps at IBus, which doesn't run in Hyprland.
        # Chromium-based flatpaks then fail to start its portal, and every
        # failure shows up as a notification. Compose works through xkb.
        unset QT_IM_MODULE QT_IM_MODULES XMODIFIERS
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
