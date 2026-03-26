# WSL module: NixOS-on-WSL2 integration.
#
# Community convention: use the nixos-wsl community module
# (github:nix-community/NixOS-WSL) for proper WSL2 support. It handles
# the virtual filesystem, Windows interop, and boot process so you don't
# have to configure these manually.
#
# The nixos-wsl input is passed via specialArgs from flake.nix.

{ config, pkgs, nixos-wsl, ... }:

{
  imports = [
    nixos-wsl.nixosModules.wsl
  ];

  wsl.enable = true;
  wsl.defaultUser = "dev";
}
