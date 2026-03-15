{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  
   outputs = { self, nixpkgs, home-manager, ... }@inputs: {
      nixosConfigurations.alcatraz = nixpkgs.lib.nixosSystem {
       system = "x86_64-linux"; 
       specialArgs = { inherit inputs; };
       modules = [
         ./alcatraz/configuration.nix
         home-manager.nixosModules.home-manager
         {
           home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.dev = import ./home/home-dev.nix;
            home-manager.users.al = import ./home/home-al.nix;
          }
      ];
    };
  };  

}
