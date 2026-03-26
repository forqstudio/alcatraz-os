# Host: alcatraz-wsl (WSL2 build)
#
# Community convention: each host gets its own directory under hosts/.
# WSL hosts don't need a hardware-configuration.nix or bootloader config
# because WSL manages the virtual hardware and boot process.
#
# The wsl.nix module (via nixos-wsl) handles all WSL2 integration.

{ config, pkgs, ... }:

{
  imports = [
    # Shared modules
    ../../modules/base.nix
    ../../modules/wsl.nix
  ];

  # --- Host-specific settings (set by the person installing) ---

  # Hostname
  networking.hostName = "alcatraz-wsl";

  # Timezone and locale (set these to match your location)
  time.timeZone = "Europe/Amsterdam";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "nl_NL.UTF-8";
    LC_IDENTIFICATION = "nl_NL.UTF-8";
    LC_MEASUREMENT = "nl_NL.UTF-8";
    LC_MONETARY = "nl_NL.UTF-8";
    LC_NAME = "nl_NL.UTF-8";
    LC_NUMERIC = "nl_NL.UTF-8";
    LC_PAPER = "nl_NL.UTF-8";
    LC_TELEPHONE = "nl_NL.UTF-8";
    LC_TIME = "nl_NL.UTF-8";
  };
}
