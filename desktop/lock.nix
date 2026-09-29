{ config, lib, pkgs, ... }:

let
  # hyprlock and hypridle come from the image (D4). The HM modules only
  # write their configs.
  dpms = action: "/usr/bin/hyprctl dispatch 'hl.dsp.dpms({action = \"${action}\"})'";
in
{
  services.hypridle = {
    enable = true;
    package = null;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || /usr/bin/hyprlock";
        # Every lock goes through logind, so the locker is always the same.
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = dpms "on";
        # Delay sleep until hyprlock has taken the session lock, so the first
        # frame after resume is the lock screen.
        inhibit_sleep = 3;
        ignore_dbus_inhibit = false;
        ignore_wayland_inhibit = false;
      };

      listener = [
        {
          timeout = 900;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 1200;
          on-timeout = dpms "off";
          on-resume = dpms "on";
        }
      ];
    };
  };

  # hypridle reads its config only at startup.
  xdg.configFile."hypr/hypridle.conf".onChange = ''
    ${pkgs.systemd}/bin/systemctl --user try-restart hypridle.service || true
  '';

  programs.hyprlock = {
    enable = true;
    package = null;
    settings = {
      input-field = [
        {
          monitor = "";
          fade_on_empty = false;
        }
      ];
    };
  };
}
