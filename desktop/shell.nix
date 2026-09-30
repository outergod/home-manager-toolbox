{ config, lib, pkgs, ... }:

let
  # Both run in the Hyprland session only (D3).
  target = config.wayland.systemd.target;

  vicinae = pkgs.vicinae;

  # Settings the desktop relies on, in a file Vicinae imports. Its own
  # settings.json stays writable for the settings screen and takes
  # precedence over imports (D9).
  vicinaeImport = "nix.json";
in
{
  # Shell and launcher chosen by the tryout (D8): Noctalia and Vicinae.

  # Only the guardrails live here; the look is in theme.nix. The settings
  # screen writes to ~/.local/state/noctalia/settings.toml, which overrides
  # config.toml (D9).
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
    settings = {
      # Its own locker would also react to logind's Lock signal.
      lockscreen.enabled = false;
      shell = {
        polkit_agent = false;
        # With the locker off, built-in lock rows are hidden, so lock is a
        # command row. Declaring rows replaces the default set.
        session.actions = [
          {
            action = "command";
            label = "Lock";
            glyph = "lock";
            command = "loginctl lock-session";
          }
          { action = "logout"; }
          { action = "suspend"; }
          { action = "reboot"; }
          {
            action = "shutdown";
            variant = "destructive";
          }
        ];
      };
      # Off by default already; hypridle is the only idle manager.
      idle.behavior = lib.genAttrs [ "lock" "screen-off" "lock-and-suspend" ] (_: {
        enabled = false;
      });
    };
  };

  # Noctalia counts as started once it owns the tray watcher, and autostart
  # apps start after that. Apps started earlier fall back to other tray
  # protocols and never show up (Bitwarden, Synology Drive).
  systemd.user.services.noctalia = {
    Service = {
      Type = "dbus";
      BusName = "org.kde.StatusNotifierWatcher";
    };
    Unit = {
      # Noctalia also tries to own org.freedesktop.ScreenSaver. hypridle has
      # to win it, or apps' D-Bus idle inhibitors never reach hypridle.
      After = [ "hypridle.service" ];
      # Noctalia reloads its config files itself. A restart would also
      # replace its tray watcher, and some apps never register again.
      X-Restart-Triggers = lib.mkForce [ ];
    };
  };
  xdg.configFile."systemd/user/app-@autostart.service.d/after-shell.conf".text = ''
    [Unit]
    After=noctalia.service
  '';

  programs.vicinae = {
    enable = true;
    package = vicinae;
    systemd = {
      enable = true;
      inherit target;
    };
  };

  xdg.configFile."vicinae/${vicinaeImport}".text = builtins.toJSON {
    # With the default "exclusive", Hyprland refuses to move focus while the
    # panel is open, so windows behind others can't be raised (D8).
    launcher_window.layer_shell.keyboard_interactivity = "on_demand";

    # Prefixes for the omnibox's other sources. An alias followed by Space
    # opens its command, and typing "power" lists all power actions. The
    # calculator also answers in plain search. Lock goes through logind.
    providers = {
      clipboard.entrypoints.history.alias = "clip";
      files.entrypoints.search.alias = "file";
      calculator.entrypoints.history.alias = "calc";
      power.entrypoints = {
        lock.alias = "power lock";
        logout.alias = "power logout";
        suspend.alias = "power suspend";
        reboot.alias = "power reboot";
        power-off.alias = "power off";
      };
    };
  };

  # settings.json belongs to Vicinae, so the import can't be added from
  # here. Point it out when it's missing.
  home.activation.vicinaeImport = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    vicinaeSettings=${lib.escapeShellArg "${config.xdg.configHome}/vicinae/settings.json"}
    if [[ -e $vicinaeSettings ]] && ! grep -q ${lib.escapeShellArg "\"${vicinaeImport}\""} "$vicinaeSettings"; then
      warnEcho "$vicinaeSettings doesn't import ${vicinaeImport}; add \"imports\": [\"${vicinaeImport}\"]"
    fi
  '';

  # Ctrl+Space and Super+Space in binds.lua.
  desktop.nixLua = {
    launcher = "${lib.getExe vicinae} toggle";
    windows = "${lib.getExe vicinae} deeplink vicinae://launch/wm/switch-windows";
  };
}
