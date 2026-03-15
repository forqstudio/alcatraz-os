# Host: alcatraz-iso (installer ISO image)
#
# Produces a bootable ISO containing the Alcatraz OS installer.
# Boot from USB, connect to the internet, then run:
#   alcatraz-install /dev/sdX
#
# Build with:
#   nix build ./src#iso
#
# Write to USB:
#   sudo dd bs=4M conv=fsync oflag=direct status=progress \
#     if=result/iso/nixos-*.iso of=/dev/sdX

{ config, pkgs, lib, self, ... }:

let
  alcatraz-install = pkgs.writeShellScriptBin "alcatraz-install" ''
    set -euo pipefail

    if [ "$(id -u)" -ne 0 ]; then
      echo "Error: alcatraz-install must be run as root."
      exit 1
    fi

    DISK="''${1:-}"
    if [ -z "$DISK" ]; then
      echo "Alcatraz OS Installer"
      echo ""
      echo "Usage: alcatraz-install <disk>"
      echo "Example: alcatraz-install /dev/sda"
      echo ""
      echo "Available disks:"
      lsblk -d -o NAME,SIZE,MODEL | grep -v loop
      exit 1
    fi

    if [ ! -b "$DISK" ]; then
      echo "Error: $DISK is not a block device."
      exit 1
    fi

    if [ ! -d /sys/firmware/efi ]; then
      echo "Error: UEFI firmware not detected."
      echo "Alcatraz OS requires a UEFI-capable system."
      exit 1
    fi

    # NVMe and eMMC disks use a 'p' separator before partition numbers
    if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
      PART="''${DISK}p"
    else
      PART="$DISK"
    fi

    echo "=== Alcatraz OS Installer ==="
    echo ""
    echo "Target disk: $DISK"
    lsblk "$DISK"
    echo ""
    echo "WARNING: ALL DATA on $DISK will be erased."
    read -p "Type 'yes' to continue: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Aborted."
      exit 0
    fi

    echo ""
    echo "[1/6] Partitioning $DISK (GPT, UEFI)..."
    parted "$DISK" -- mklabel gpt
    parted "$DISK" -- mkpart ESP fat32 1MB 512MB
    parted "$DISK" -- set 1 esp on
    parted "$DISK" -- mkpart root ext4 512MB -8GB
    parted "$DISK" -- mkpart swap linux-swap -8GB 100%

    echo "[2/6] Formatting..."
    mkfs.fat -F 32 -n boot "''${PART}1"
    mkfs.ext4 -L nixos "''${PART}2"
    mkswap -L swap "''${PART}3"

    echo "[3/6] Mounting..."
    mount /dev/disk/by-label/nixos /mnt
    mkdir -p /mnt/boot
    mount /dev/disk/by-label/boot /mnt/boot
    swapon /dev/disk/by-label/swap

    echo "[4/6] Copying configuration..."
    mkdir -p /mnt/etc/nixos
    cp -r /etc/alcatraz/* /mnt/etc/nixos/

    echo "[5/6] Detecting hardware..."
    nixos-generate-config --root /mnt --dir /tmp/hw-config
    cp /tmp/hw-config/hardware-configuration.nix \
      /mnt/etc/nixos/src/hosts/alcatraz/hardware-configuration.nix

    # Replace GRUB (legacy) bootloader with systemd-boot (UEFI)
    CONF="/mnt/etc/nixos/src/hosts/alcatraz/configuration.nix"
    sed -i 's|boot.loader.grub.enable = true;|boot.loader.systemd-boot.enable = true;|' "$CONF"
    sed -i 's|boot.loader.grub.device = .*|boot.loader.efi.canTouchEfiVariables = true;|' "$CONF"
    sed -i '/boot.loader.grub.useOSProber/d' "$CONF"

    echo "[6/6] Installing Alcatraz OS (this will take a while)..."
    nixos-install --flake /mnt/etc/nixos/src#alcatraz

    echo ""
    echo "=== Installation complete ==="
    echo "Remove the installation media and reboot."
  '';

in
{
  environment.systemPackages = with pkgs; [
    alcatraz-install
    vim
    git
    parted
    gptfdisk
  ];

  # Make the flake source available at /etc/alcatraz in the live environment
  environment.etc."alcatraz".source = self;

  # Use fast compression during development. For release builds, remove this
  # line to use the default xz compression (smaller file, slower build).
  isoImage.squashfsCompression = "gzip -Xcompression-level 1";
}
