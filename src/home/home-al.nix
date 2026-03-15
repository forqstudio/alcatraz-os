{ config, pkgs, ... }:

{
  imports = [ ./home-common.nix ];
  home.packages = with pkgs; [
    git
    ripgrep
    fd
    tree
  ];
}
