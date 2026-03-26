# Base module: universal configuration shared across all hosts.
#
# Community convention: shared modules live in modules/ and contain only
# settings that apply to every machine. Host-specific settings (hostname,
# locale, timezone, bootloader, hardware) belong in each host's own
# configuration.nix under hosts/<hostname>/.

{ config, pkgs, ... }:

{
  # Enable networking via NetworkManager (common to all hosts)
  networking.networkmanager.enable = true;

  # User accounts
  users.users.dev = {
    isNormalUser = true;
    description = "dev";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  users.users.al = {
    isNormalUser = true;
    description = "al";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable flakes and the new nix command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # NixOS release version for stateful data compatibility.
  # Set once at initial install; do not change without reading the docs.
  system.stateVersion = "25.11";
}
