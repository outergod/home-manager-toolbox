{ config, lib, pkgs, ... }:

let
  # hyprlock and hypridle come from the image (D4). The HM modules only
  # write their configs.
  dpms = action: "/usr/bin/hyprctl dispatch 'hl.dsp.dpms({action = \"${action}\"})'";

  inherit (config.desktop.theme) palette fonts wallpaper;
  rgb = c: "rgb(${c})";
  rgba = c: alpha: "rgba(${c}${alpha})";
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
    # The desktop's look (theme.nix): the wallpaper, blurred and darkened,
    # the bar's bold Noto Sans, and a square field on black with the
    # accent as its outline.
    settings = with palette; {
      general.hide_cursor = true;

      background = [
        {
          monitor = "";
          path = "${wallpaper}";
          blur_passes = 3;
          brightness = 0.6;
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          font_family = "${fonts.sans} Bold";
          font_size = 90;
          color = rgb nord6;
          position = "0, 160";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:60000] date +"%A, %F"'';
          font_family = "${fonts.sans} Bold";
          font_size = 20;
          color = rgb nord4;
          position = "0, 60";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          fade_on_empty = false;
          size = "300, 50";
          position = "0, -40";
          halign = "center";
          valign = "center";
          rounding = 0;
          outline_thickness = 2;
          outer_color = rgb accent;
          inner_color = rgba black "cc";
          font_color = rgb nord6;
          font_family = fonts.sans;
          placeholder_text = "";
          check_color = rgb nord12;
          fail_color = rgb nord11;
          fail_text = "$PAMFAIL";
        }
      ];
    };
  };
}
