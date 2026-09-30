{ config, lib, pkgs, ... }:

let
  # Emacs and Zed run inside the nix distrobox. Their launcher entries are the
  # container-exported and chezmoi-managed ones in ~/.local/share/applications,
  # so the host-profile copies are dropped. The binaries stay, since those
  # entries run ~/.nix-profile/bin/* inside the container (D11).
  #
  # Copies the outputs as symlinks instead of rebuilding.
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
    package = withoutDesktopEntries pkgs.zed-editor;
  };

  # Starts the container at login in any session, so container-launched apps
  # don't wait for its init on first use. The first start runs distrobox's
  # init, hence the generous timeout.
  #
  # The container's conmon stays in this unit's cgroup when the unit starts
  # it. Stopping the unit, e.g. when a switch restarts it, must not kill the
  # container and everything running in it.
  systemd.user.services.distrobox-nix = {
    Unit.Description = "Start the nix distrobox container";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/usr/bin/distrobox enter nix -- true";
      TimeoutStartSec = "10min";
      KillMode = "process";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Gives the container the host's GPU drivers (home.nix). The container's
  # /run is its own, and container root can't run the setup script, which
  # writes the host's gcroots. This unit changes with the drivers, so a
  # switch restarts it and updates the link. It only execs into the running
  # container and never starts or stops it.
  systemd.user.services.distrobox-nix-gpu = {
    Unit = {
      Description = "Link GPU drivers into the nix distrobox container";
      Requires = [ "distrobox-nix.service" ];
      After = [ "distrobox-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/usr/bin/podman exec --user root nix ln -sfn ${config.targets.genericLinux.gpu.drivers} /run/opengl-driver";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
