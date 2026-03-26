# Bootloader configuration (machine-specific)
#
# BIOS / GRUB — matches the developer's current machine.
# The ISO installer overwrites this file with UEFI / systemd-boot
# settings for fresh installs. Option 3 users should edit this file
# to match their system.

{
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";
  boot.loader.grub.useOSProber = true;
}
