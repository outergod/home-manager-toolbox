{ config, lib, pkgs, ... }:

let
  cfg = config.desktop;

  # Every candidate runs in the Hyprland session only (D3).
  target = config.wayland.systemd.target;

  # Binds a unit from an HM module to the Hyprland session, for modules that
  # hardcode graphical-session.target instead of following
  # wayland.systemd.target.
  onTarget = after: {
    Unit = {
      After = lib.mkForce ([ target ] ++ after);
      PartOf = lib.mkForce [ target ];
    };
    Install.WantedBy = lib.mkForce [ target ];
  };

  # dms runs Quickshell as `qs` from PATH, and the nixpkgs package doesn't
  # bring it along.
  dms = pkgs.symlinkJoin {
    inherit (pkgs.dms-shell) name meta;
    paths = [ pkgs.dms-shell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/dms --prefix PATH : ${pkgs.quickshell}/bin
    '';
  };

  # DMS has no setting to turn its locker off, but routes every lock button
  # through customPowerActionLock. Without logind integration it ignores
  # Lock signals and suspend. Its idle timers are off at 0.
  dmsGuardrails = {
    loginctlLockIntegration = false;
    lockBeforeSuspend = false;
    lockAtStartup = false;
    customPowerActionLock = "loginctl lock-session";
  }
  // lib.genAttrs (lib.concatMap (p: map (t: "${p}${t}Timeout") [ "Lock" "Monitor" "Suspend" "PostLockMonitor" ]) [
    "ac"
    "battery"
  ]) (_: 0);

  noctalia = pkgs.noctalia;
  vicinae = pkgs.vicinae;
  walker = pkgs.walker;
in
{
  # The shell and launcher tryout (D8). Only the selected combination is
  # installed and started; switching is a one-line change.
  options.desktop = {
    shell = lib.mkOption {
      type = lib.types.enum [ "dms" "noctalia" "none" ];
      default = "none";
      description = "Desktop shell providing bar, notifications and OSD.";
    };

    launcher = lib.mkOption {
      type = lib.types.enum [ "builtin" "vicinae" "walker" "none" ];
      default = "none";
      description = "Omnibox on Super+Space. `builtin` uses the shell's own.";
    };
  };

  config = lib.mkMerge [
    {
      desktop.shell = "noctalia";
      desktop.launcher = "vicinae";

      assertions = [
        {
          assertion = cfg.launcher == "builtin" -> cfg.shell != "none";
          message = "desktop.launcher = \"builtin\" needs a desktop.shell.";
        }
      ];
    }

    (lib.mkIf (cfg.shell == "dms") {
      home.packages = [ dms ];

      systemd.user.services.dms = {
        Unit = {
          Description = "DankMaterialShell";
          PartOf = [ target ];
          # DMS also tries to own org.freedesktop.ScreenSaver, which
          # hypridle needs for apps' D-Bus idle inhibitors.
          After = [ target "hypridle.service" ];
        };
        Service = {
          ExecStart = "${lib.getExe dms} run --session";
          ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
          # Its polkit agent can only be turned off here.
          Environment = [ "DMS_DISABLE_POLKIT=1" ];
          Restart = "on-failure";
          RestartForceExitStatus = "TEMPFAIL";
          SuccessExitStatus = "TEMPFAIL";
        };
        Install.WantedBy = [ target ];
      };

      # The settings screen rewrites settings.json, and a read-only one
      # makes it drop every change. So the file stays native and writable
      # (D9), and each switch only forces the guardrail keys back in.
      home.activation.dmsGuardrails = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        dmsSettings=${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell/settings.json"}
        dmsTmp=$(mktemp)
        if { cat "$dmsSettings" 2>/dev/null || true; } | ${lib.getExe pkgs.jq} -s \
            --argjson g ${lib.escapeShellArg (builtins.toJSON dmsGuardrails)} \
            '(.[0] // {}) + $g' > "$dmsTmp"; then
          if ! cmp -s "$dmsTmp" "$dmsSettings"; then
            run mkdir -p "$(dirname "$dmsSettings")"
            run cp "$dmsTmp" "$dmsSettings"
          fi
        else
          warnEcho "Could not apply the DMS guardrails to $dmsSettings"
        fi
        rm -f "$dmsTmp"
      '';
    })

    (lib.mkIf (cfg.shell == "dms" && cfg.launcher == "builtin") {
      desktop.nixLua.launcher = "${lib.getExe dms} ipc call spotlight toggle";
    })

    (lib.mkIf (cfg.shell == "noctalia") {
      # Only the guardrails live in config.toml. The settings screen writes
      # to ~/.local/state/noctalia/settings.toml, which overrides it (D9).
      programs.noctalia = {
        enable = true;
        package = noctalia;
        systemd.enable = true;
        settings = {
          # Its own locker would also react to logind's Lock signal.
          lockscreen.enabled = false;
          shell = {
            polkit_agent = false;
            # With the locker off, built-in lock rows are hidden, so lock is
            # a command row. Declaring rows replaces the default set.
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
      # Noctalia counts as started once it owns the tray watcher, and
      # autostart apps start after that. Apps started earlier fall back to
      # other tray protocols and never show up (Bitwarden, Synology Drive).
      systemd.user.services.noctalia.Service = {
        Type = "dbus";
        BusName = "org.kde.StatusNotifierWatcher";
      };
      xdg.configFile."systemd/user/app-@autostart.service.d/after-shell.conf".text = ''
        [Unit]
        After=noctalia.service
      '';

      systemd.user.services.noctalia.Unit = {
        # Noctalia also tries to own org.freedesktop.ScreenSaver. hypridle
        # has to win it, or apps' D-Bus idle inhibitors never reach hypridle.
        After = [ "hypridle.service" ];
        # Noctalia reloads its config files itself. A restart would also
        # replace its tray watcher, and some apps (Bitwarden, Synology
        # Drive) never register their tray icons again.
        X-Restart-Triggers = lib.mkForce [ ];
      };
    })

    (lib.mkIf (cfg.shell == "noctalia" && cfg.launcher == "builtin") {
      desktop.nixLua = {
        launcher = "${lib.getExe noctalia} msg panel-toggle launcher";
        windows = "${lib.getExe noctalia} msg panel-toggle launcher '/win '";
      };
    })

    (lib.mkIf (cfg.launcher == "vicinae") {
      programs.vicinae = {
        enable = true;
        package = vicinae;
        systemd = {
          enable = true;
          inherit target;
        };
      };
      desktop.nixLua = {
        launcher = "${lib.getExe vicinae} toggle";
        windows = "${lib.getExe vicinae} deeplink vicinae://launch/wm/switch-windows";
      };
    })

    (lib.mkIf (cfg.launcher == "walker") {
      services.elephant.enable = true;
      services.walker = {
        enable = true;
        package = walker;
        systemd.enable = true;
      };
      systemd.user.services.elephant = onTarget [ ];
      systemd.user.services.walker = onTarget [ "elephant.service" ];
      desktop.nixLua = {
        launcher = lib.getExe walker;
        windows = "${lib.getExe walker} --provider windows";
      };
    })
  ];
}
