{
  description = "Gjermund's NixOS configuration with Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixvim, zen-browser, ... }@inputs:
  let
    # Common modules shared between all hosts
    commonModules = [
      nixvim.nixosModules.nixvim
      home-manager.nixosModules.home-manager
      ./modules/common.nix
      ./theming.nix
    ];

    # Helper function to create a NixOS configuration
    mkHost = { hostName, hostModules ? [], extraArgs ? {} }: nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs hostName;
      } // extraArgs;
      modules = commonModules ++ hostModules ++ [
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          networking.hostName = hostName;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs hostName; };
          home-manager.users.gjermund = import ./modules/home.nix;
        }
      ];
    };
  in
  {
    nixosConfigurations = {
      # Desktop: RTX 5070 Ti, 5120x1440@240Hz ultrawide
      desktop = mkHost {
        hostName = "desktop";
        hostModules = [
          ./hosts/desktop/hardware-configuration.nix
          ./hosts/desktop/nvidia.nix
          ./hosts/desktop/default.nix
        ];
      };

      # Laptop: Intel + NVIDIA hybrid (Prime), 2560x1440@60Hz
      laptop = mkHost {
        hostName = "laptop";
        hostModules = [
          ./hosts/laptop/hardware-configuration.nix
          ./hosts/laptop/nvidia-prime.nix
          ./hosts/laptop/default.nix
        ];
      };
    };
  };
}
