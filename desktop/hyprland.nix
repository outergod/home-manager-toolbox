{ config, lib, pkgs, ... }:

let
  toLua = lib.generators.toLua { };

  # The static Lua modules are linked from the working tree, not the store,
  # so saving a file is enough for Hyprland to pick it up.
  hyprSrc = "${config.xdg.configHome}/home-manager/desktop/hypr";
  luaModules = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".lua" name
  ) (builtins.readDir ./hypr);

  # HM only reloads Hyprland when it installs the package itself. hyprctl
  # only exists on the host, so this is a no-op when switching elsewhere.
  reloadHyprland = ''
    if [[ -x /usr/bin/hyprctl && -d "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" ]]; then
      for i in $(/usr/bin/hyprctl instances -j | ${lib.getExe pkgs.jq} -r '.[].instance'); do
        /usr/bin/hyprctl -i "$i" reload || true
      done
    fi
  '';
in
{
  # Nix-derived values for the static Lua, loaded with require("nix").
  # Other modules add their own, e.g. the launcher command.
  options.desktop.nixLua = lib.mkOption {
    type = with lib.types; attrsOf (nullOr str);
    default = { };
    description = "Values exposed to the Hyprland Lua config as the `nix` module.";
  };

  config.desktop.nixLua = {
    terminal = lib.getExe config.programs.foot.package;
    playerctl = lib.getExe pkgs.playerctl;
  };

  config.wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    # Hyprland, its portal and uwsm come from the image.
    package = null;
    portalPackage = null;
    systemd.enable = false;

    extraLuaFiles.nix = {
      autoLoad = false;
      content = "return ${toLua config.desktop.nixLua}\n";
    };

    extraConfig = ''
      local hypr_dir = (os.getenv("XDG_CONFIG_HOME") or ${toLua config.xdg.configHome}) .. "/hypr"
      package.path = hypr_dir .. "/?.lua;" .. package.path
      require("desktop")
    '';
  };

  config.xdg.configFile = lib.mkMerge [
    (lib.mapAttrs' (
      name: _:
      lib.nameValuePair "hypr/${name}" {
        source = config.lib.file.mkOutOfStoreSymlink "${hyprSrc}/${name}";
      }
    ) luaModules)
    {
      "hypr/hyprland.lua".onChange = reloadHyprland;
      "hypr/nix.lua".onChange = reloadHyprland;

      # The stubs ship with the image. Editors in the nix container see the
      # host's /usr under /run/host.
      "hypr/.luarc.json".text = builtins.toJSON {
        workspace.library = [
          "/usr/share/hypr/stubs"
          "/run/host/usr/share/hypr/stubs"
        ];
        diagnostics.globals = [ "hl" ];
      };
    }
  ];
}
