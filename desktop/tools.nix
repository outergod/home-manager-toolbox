{ config, lib, pkgs, ... }:

{
  # Fallback terminal. It renders on the CPU, so it is deliberately not
  # nixGL-wrapped and keeps working when GL is broken.
  programs.foot.enable = true;
}
