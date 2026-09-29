# Hyprland desktop, one module per concern. See
# openspec/changes/hyprland-desktop/design.md (D1).
{
  imports = [
    ./hyprland.nix
    ./session.nix
    ./lock.nix
    ./shell.nix
    ./tools.nix
    ./container.nix
    ./theme.nix
  ];
}
