{ config, lib, pkgs, ... }:

let
  inherit (config.desktop.theme) palette fonts cursor;
  hex = c: "#${c}";
in
{
  # The desktop's look in one place (D13). Other modules read it, e.g. the
  # lock screen (lock.nix) and the session's cursor (session.nix).
  options.desktop.theme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Palette, fonts, cursor and wallpaper shared by the desktop.";
    default = {
      # Nord, on pure black, with Nord yellow as the one accent instead of
      # the frost greens and blues. Plain RRGGBB, as foot wants them.
      palette = rec {
        black = "000000";
        nord0 = "2e3440";
        nord1 = "3b4252";
        nord2 = "434c5e";
        nord3 = "4c566a";
        nord4 = "d8dee9";
        nord5 = "e5e9f0";
        nord6 = "eceff4";
        nord7 = "8fbcbb";
        nord8 = "88c0d0";
        nord9 = "81a1c1";
        nord10 = "5e81ac";
        nord11 = "bf616a";
        nord12 = "d08770";
        nord13 = "ebcb8b";
        nord14 = "a3be8c";
        nord15 = "b48ead";
        accent = nord13;
      };

      # GNOME's interface and monospace fonts. GTK apps take theirs from
      # GNOME's settings, which already name these.
      fonts = {
        sans = "Noto Sans";
        mono = "Fira Code";
        monoSize = 10;
      };

      # Adwaita, as in GNOME. It comes with the image and has no hyprcursor
      # variant, so Hyprland uses the XCursor theme.
      cursor = {
        name = "Adwaita";
        size = 24;
      };

      # The libadwaita look for GTK3 apps, in dark. Libadwaita apps ignore
      # it. The image ships it; flatpak installs the matching
      # org.gtk.Gtk3theme runtime on update, as it does for any active theme.
      gtkTheme = "adw-gtk3-dark";

      wallpaper = ./wallpaper.jpg;
    };
  };

  # GTK3's Adwaita ignores the dark preference, so GTK3 apps need a dark
  # theme. The GTK theme and cursor are GNOME settings, read by GTK apps in
  # both sessions and by flatpaks through the portal. The dark preference
  # itself (color-scheme) is set by Noctalia.
  config.dconf.settings."org/gnome/desktop/interface" = {
    gtk-theme = config.desktop.theme.gtkTheme;
    cursor-theme = cursor.name;
    cursor-size = cursor.size;
  };

  # Qt 5 ignores the dark preference, so Qt flatpaks on KDE's Qt 5 runtime
  # (Picard, MakeMKV) are light. Their runtime has KDE's platform theme,
  # which takes its colours from kdeglobals: Breeze Dark, copied so the
  # generation doesn't depend on Breeze. Flatpaks without that plugin ignore
  # the variable. The image's own Qt apps (hyprpolkitagent, hyprland-dialog)
  # are dark already.
  config.xdg.configFile."kdeglobals".source = pkgs.runCommandLocal "kdeglobals" { } ''
    cp ${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors $out
  '';
  config.xdg.dataFile."flatpak/overrides/global".text = ''
    [Environment]
    QT_QPA_PLATFORMTHEME=kde
  '';

  # Nix apps (foot, Noctalia, Vicinae) find the image's fonts through Nix's
  # fontconfig, which keeps a cache of its own in ~/.cache/fontconfig. The
  # image's font directories all have mtime 0 (ostree), so that cache never
  # notices new fonts and goes stale with image updates. Those need a
  # reboot, so rebuilding it at login, before the session, whenever the
  # image's fonts have changed catches all of them.
  config.systemd.user.services.fontconfig-cache-nix = {
    Unit = {
      Description = "Rebuild Nix's fontconfig cache when the image's fonts change";
      Before = [ "graphical-session-pre.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "fontconfig-cache-nix";
          runtimeInputs = with pkgs; [ coreutils findutils fontconfig.bin ];
          text = ''
            stamp=''${XDG_CACHE_HOME:-$HOME/.cache}/fontconfig/nix-image-fonts
            fonts=$(find /usr/share/fonts -printf '%P %s\n' | sort | sha256sum)
            if [[ -f $stamp && $(<"$stamp") == "$fonts" ]]; then
              exit 0
            fi
            fc-cache -f
            mkdir -p "''${stamp%/*}"
            printf '%s\n' "$fonts" >"$stamp"
          '';
        }
      );
    };
    Install.WantedBy = [ "default.target" ];
  };

  # The fallback terminal: Nord colours on black at 90%, a little more
  # opaque than the bar for reading.
  config.programs.foot.settings = {
    main.font = "${fonts.mono}:size=${toString fonts.monoSize}";
    colors-dark = with palette; {
      alpha = 0.9;
      foreground = nord4;
      background = black;
      selection-foreground = nord0;
      selection-background = nord4;
      cursor = "${black} ${nord6}";
      regular0 = nord1;
      regular1 = nord11;
      regular2 = nord14;
      regular3 = nord13;
      regular4 = nord9;
      regular5 = nord15;
      regular6 = nord8;
      regular7 = nord5;
      bright0 = "596377";
      bright1 = nord11;
      bright2 = nord14;
      bright3 = nord13;
      bright4 = nord9;
      bright5 = nord15;
      bright6 = nord7;
      bright7 = nord6;
    };
  };

  # The old waybar look on Noctalia. A bar flush with the top edge, full
  # width, square, black at 80%, flat modules, bold Noto Sans at about 12px.
  # Guardrails stay in shell.nix; the settings screen still overrides all of
  # this.
  config.programs.noctalia = {
    # Snow and orange are the secondary and tertiary colours, and the accent
    # also outlines floating panels. Noctalia rejects a palette without a
    # terminal block, although with its templates off nothing uses it.
    customPalettes.NordGold.dark = with palette; {
      mPrimary = hex accent;
      mOnPrimary = hex nord0;
      mSecondary = hex nord4;
      mOnSecondary = hex nord0;
      mTertiary = hex nord12;
      mOnTertiary = hex nord0;
      mError = hex nord11;
      mOnError = hex nord0;
      mSurface = hex nord0;
      mOnSurface = hex nord6;
      mSurfaceVariant = hex nord1;
      mOnSurfaceVariant = hex nord4;
      mOutline = hex accent;
      mShadow = hex nord0;
      mHover = hex nord3;
      mOnHover = hex nord6;
      terminal = {
        normal = lib.mapAttrs (_: hex) {
          black = nord1;
          red = nord11;
          green = nord14;
          yellow = nord13;
          blue = nord9;
          magenta = nord15;
          cyan = nord8;
          white = nord5;
        };
        bright = lib.mapAttrs (_: hex) {
          black = "596377";
          red = nord11;
          green = nord14;
          yellow = nord13;
          blue = nord9;
          magenta = nord15;
          cyan = nord7;
          white = nord6;
        };
        foreground = hex nord4;
        background = hex nord0;
        selectionFg = hex nord3;
        selectionBg = hex nord6;
        cursorText = "#282828";
        cursor = hex nord6;
      };
    };

    settings = {
      shell = {
        font_family = fonts.sans;
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

      # On both monitors. From the store, so it changes only with the image.
      # A wallpaper picked in Noctalia's panel lands in settings.toml and
      # takes precedence.
      wallpaper.default.path = "${config.desktop.theme.wallpaper}";

      notification.background_opacity = 0.8;
      osd.background_opacity = 0.8;

      # Replaces Noctalia's default bar. It shows on both monitors; a
      # `monitor.<output>.enabled = false` table would leave one out.
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
