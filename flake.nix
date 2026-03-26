{
  description = "Alcatraz OS - NixOS configurations for bare-metal and WSL2";

  # Community convention: pin all third-party inputs to follow the same
  # nixpkgs to avoid multiple evaluations and ensure consistency.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, disko, nixos-wsl, ... }@inputs:
  let
    system = "x86_64-linux";

    # Shared Home Manager configuration used by both hosts.
    # Community convention: define home-manager as a NixOS module so that
    # user environments are managed declaratively alongside the system.
    homeManagerModule = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.dev = import ./home/home-dev.nix;
      home-manager.users.al = import ./home/home-al.nix;
    };
  in
  {
    # Community convention: each machine is a named entry under
    # nixosConfigurations. Build/switch with:
    #   sudo nixos-rebuild switch --flake .#<hostname>

    # Bare-metal graphical install
    nixosConfigurations.alcatraz = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs nixos-wsl; };
      modules = [
        ./hosts/alcatraz/configuration.nix
        home-manager.nixosModules.home-manager
        homeManagerModule
      ];
    };

    # Installer ISO
    nixosConfigurations.alcatraz-iso = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs self; };
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
        ./hosts/alcatraz-iso/configuration.nix
      ];
    };

    # WSL2 build
    nixosConfigurations.alcatraz-wsl = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs nixos-wsl; };
      modules = [
        ./hosts/alcatraz-wsl/configuration.nix
        home-manager.nixosModules.home-manager
        homeManagerModule
      ];
    };

    # WSL tarball builder.
    # The nixos-wsl module exposes a tarballBuilder script that produces a
    # .wsl file (tar.gz) importable by WSL on Windows.
    #
    # Build with:
    #   sudo nix run .#alcatraz-wsl-tarball
    #
    # Then on Windows:
    #   wsl --install --from-file nixos.wsl        (WSL >= 2.4.4)
    #   wsl --import NixOS <path> nixos.wsl        (older WSL)
    packages.${system} = {
      alcatraz-wsl-tarball =
        self.nixosConfigurations.alcatraz-wsl.config.system.build.tarballBuilder;

      # Build with: nix build .#iso
      # Result at: result/iso/nixos-*.iso
      iso =
        self.nixosConfigurations.alcatraz-iso.config.system.build.isoImage;
    };
  };
}
