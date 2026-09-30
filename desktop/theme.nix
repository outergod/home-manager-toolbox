{ config, lib, pkgs, ... }:

{
  # Look trial (D13): the old waybar look on Noctalia. A bar flush with the
  # top edge, full width, square, black at 80%, flat modules, bold Noto Sans
  # at about 12px. Nord accents on a pure black surface. Guardrails stay in
  # shell.nix; the settings screen still overrides all of this.
  programs.noctalia = lib.mkIf (config.desktop.shell == "noctalia") {
    # Nord, with Nord yellow as the one accent instead of the frost greens
    # and blues: outlines (floating panel borders), primary accents, and
    # snow and orange as secondary and tertiary. Noctalia rejects a palette
    # without a terminal block.
    customPalettes.NordGold.dark = {
      mPrimary = "#ebcb8b";
      mOnPrimary = "#2e3440";
      mSecondary = "#d8dee9";
      mOnSecondary = "#2e3440";
      mTertiary = "#d08770";
      mOnTertiary = "#2e3440";
      mError = "#bf616a";
      mOnError = "#2e3440";
      mSurface = "#2e3440";
      mOnSurface = "#eceff4";
      mSurfaceVariant = "#3b4252";
      mOnSurfaceVariant = "#d8dee9";
      mOutline = "#ebcb8b";
      mShadow = "#2e3440";
      mHover = "#4c566a";
      mOnHover = "#eceff4";
      terminal = {
        normal = {
          black = "#3b4252";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#88c0d0";
          white = "#e5e9f0";
        };
        bright = {
          black = "#596377";
          red = "#bf616a";
          green = "#a3be8c";
          yellow = "#ebcb8b";
          blue = "#81a1c1";
          magenta = "#b48ead";
          cyan = "#8fbcbb";
          white = "#eceff4";
        };
        foreground = "#d8dee9";
        background = "#2e3440";
        selectionFg = "#4c566a";
        selectionBg = "#eceff4";
        cursorText = "#282828";
        cursor = "#eceff4";
      };
    };

    settings = {
      shell = {
        font_family = "Noto Sans";
        # Square panels, launcher, notifications and OSD. The bar has its
        # own radius keys.
        corner_radius_scale = 0.0;

        # Panels float, so they get borders, and open under the bar item
        # that opened them.
        panel =
          lib.genAttrs (map (p: "${p}_placement") [ "control_center" "session" "wallpaper" ]) (_: "floating")
          // lib.genAttrs (map (p: "open_near_click_${p}") [
            "control_center"
            "session"
            "wallpaper"
            "clipboard"
          ]) (_: true);
      };

      theme = {
        source = "custom";
        custom_palette = "NordGold";
        mode = "dark";
        pure_black_dark = true;
      };

      notification.background_opacity = 0.8;
      osd.background_opacity = 0.8;

      # Replaces Noctalia's default bar.
      bar.default = {
        position = "top";
        thickness = 26;
        margin_edge = 0;
        margin_ends = 0;
        radius = 0;
        radius_top_left = 0;
        radius_top_right = 0;
        radius_bottom_left = 0;
        radius_bottom_right = 0;
        shadow = false;
        background_opacity = 0.8;
        capsule = false;
        font_weight = 700;
        # Labels are 14 px at scale 1.
        font_scale = 0.86;
        start = [ "logo" "active_window" ];
        center = [ ];
        end = [
          "tray"
          "caffeine"
          "notifications"
          "bluetooth"
          "volume"
          "network"
          "keyboard_layout"
          "clock"
          "session"
        ];
      };

      widget = {
        logo = {
          type = "custom_button";
          custom_image = "/usr/share/icons/hicolor/scalable/places/bazzite-logo.svg";
          custom_image_colorize = false;
          tooltip = "Bazzite";
          actions.left = "panel-toggle control-center home";
        };
        active_window = {
          display = "icon_and_text";
          # The center lane is empty, so the title can take most of the bar.
          # 800 is the maximum.
          max_length = 800;
        };
        clock.format = "{:%F %H:%M}";
      };
    };
  };
}
