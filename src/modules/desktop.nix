# Desktop module: graphical environment, sound, and printing.
#
# Community convention: modules are split by concern. This module contains
# everything needed for a GUI desktop experience. Hosts that run headless
# or under WSL should not import this module.

{ config, pkgs, ... }:

{
  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Enable the XFCE Desktop Environment with LightDM
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents
  services.printing.enable = true;

  # Enable sound with PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Install Firefox
  programs.firefox.enable = true;
}
