{ config, pkgs, ... }:

{
  imports = [ ./home-common.nix ];
  home.packages = with pkgs; [
    git 
    vim 
    mc 
    htop 
    vscodium 
    opencode
    nixd
  ];
}
