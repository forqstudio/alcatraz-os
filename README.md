# Alcatraz OS

A NixOS-based operating system for AI-assisted software development. Ships with
two user accounts: `dev` (human developer) and `al` (AI coding agent), each with
their own tailored tool set.

## Getting Alcatraz OS

### Option 1: Install from ISO (bare-metal)

Requires a UEFI-capable x86_64 machine and internet access during install.

1. Build the ISO (or download from Releases):
   ```
   nix build .#iso
   ```
2. Write it to a USB drive:
   ```
   sudo dd bs=4M conv=fsync oflag=direct status=progress \
     if=result/iso/nixos-minimal-26.05.20260313.c06b4ae-x86_64-linux.iso of=/dev/sdb1

   sudo umount /dev/sdb1 && sudo dd if=result/iso/nixos-minimal-26.05.20260313.c06b4ae-x86_64-linux.iso of=/dev/sdb bs=4M status=progress oflag=sync

   ```
3. Boot from the USB and run:
   ```
   alcatraz-install /dev/sda
   ```
4. Remove the USB and reboot.

### Option 2: WSL 2 (Windows)

1. Build the tarball (or download from Releases):
   ```
   sudo nix run .#alcatraz-wsl-tarball
   ```
2. Import into WSL:
   ```
   wsl --install --from-file nixos.wsl
   ```
   For WSL older than 2.4.4:
   ```
   wsl --import NixOS <install-path> nixos.wsl
   ```

### Option 3: Existing NixOS installation

1. Clone the repo:
   ```
   git clone https://github.com/forqstudio/alcatraz-os.git
   ```
2. Add your hardware config — either copy your existing one or generate a new one:
   ```
   cp /etc/nixos/hardware-configuration.nix \
     ./alcatraz-os/hosts/alcatraz/hardware-configuration.nix
   ```
   or:
   ```
   sudo nixos-generate-config --dir ./alcatraz-os/hosts/alcatraz/
   ```
3. Edit `hosts/alcatraz/bootloader.nix` to match your system (UEFI
   systemd-boot or BIOS GRUB) and `configuration.nix` for locale settings.
4. Test the configuration:
   ```
   sudo nixos-rebuild test --flake ./alcatraz-os#alcatraz
   ```
5. Apply the configuration:
   ```
   sudo nixos-rebuild switch --flake ./alcatraz-os#alcatraz
   ```

## Building from source

Requires Nix with flakes enabled.

| Artifact | Command | Output |
|----------|---------|--------|
| ISO image | `nix build .#iso` | `result/iso/nixos-*.iso` |
| WSL tarball | `sudo nix run .#alcatraz-wsl-tarball` | `nixos.wsl` |

## Project structure

```
flake.nix                        # Flake entry point (inputs, outputs)
hosts/
  alcatraz/                      # Bare-metal host config
    bootloader.nix               # Bootloader settings (overwritten by installer)
  alcatraz-iso/                  # Installer ISO config
    disko-config.nix             # Declarative disk layout (used by installer)
  alcatraz-wsl/                  # WSL 2 host config
modules/
  base.nix                       # Shared settings (users, networking, nix)
  desktop.nix                    # Graphical environment (XFCE, PipeWire)
  wsl.nix                        # WSL 2 integration
home/
  home-common.nix                # Shared home-manager base
  home-dev.nix                   # dev user packages
  home-al.nix                    # al (AI agent) user packages
```
