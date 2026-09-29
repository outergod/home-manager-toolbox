{ config, lib, pkgs, ... }:

let
  # Emacs and Zed run inside the nix distrobox. Their launcher entries are the
  # container-exported and chezmoi-managed ones in ~/.local/share/applications,
  # so the host-profile copies are dropped. The binaries stay, since those
  # entries run ~/.nix-profile/bin/* inside the container (D11).
  #
  # Copies the outputs as symlinks instead of rebuilding, like nixGL's wrap.
  withoutDesktopEntries = pkg:
    pkg.overrideAttrs (old: {
      inherit (pkg) name;
      separateDebugInfo = false;
      buildCommand = ''
        ${lib.concatMapStrings (output: ''
          cp -rs --no-preserve=mode "${pkg.${output}}" "''$${output}"
        '') (old.outputs or [ "out" ])}
        rm -rf $out/share/applications
      '';
    });
in
{
  home.packages = [
    (withoutDesktopEntries ((pkgs.emacsPackagesFor pkgs.emacs-unstable-pgtk).emacsWithPackages (
      epkgs: [ epkgs.vterm ]
    )))
  ];

  programs.zed-editor = {
    enable = true;
    package = withoutDesktopEntries (config.lib.nixGL.wrap pkgs.zed-editor);
  };

  # Starts the container at login in any session, so container-launched apps
  # don't wait for its init on first use. The first start runs distrobox's
  # init, hence the generous timeout.
  systemd.user.services.distrobox-nix = {
    Unit.Description = "Start the nix distrobox container";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/usr/bin/distrobox enter nix -- true";
      TimeoutStartSec = "10min";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
