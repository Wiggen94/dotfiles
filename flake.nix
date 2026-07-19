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

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-overlay = {
      url = "github:ryoppippi/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop-linux = {
      url = "github:stslex/claude-desktop-linux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-cowork-service = {
      url = "github:patrickjaja/claude-cowork-service";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixvim,
      ...
    }@inputs:
    let
      # Common modules shared between all hosts
      commonModules = [
        nixvim.nixosModules.nixvim
        home-manager.nixosModules.home-manager
        inputs.nix-index-database.nixosModules.nix-index
        inputs.claude-cowork-service.nixosModules.default
        ./modules/common.nix
        ./theming.nix
      ];

      # Helper function to create a NixOS configuration
      mkHost =
        {
          hostName,
          hostModules ? [ ],
          extraArgs ? { },
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs hostName;
          }
          // extraArgs;
          modules =
            commonModules
            ++ hostModules
            ++ [
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
      # `nix fmt` — RFC 166 / official Nix formatter (pkgs.nixfmt == nixfmt-rfc-style)
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      nixosConfigurations = {
        # Desktop: RTX 5070 Ti, 5120x1440@240Hz ultrawide
        desktop = mkHost {
          hostName = "desktop";
          hostModules = [
            inputs.hermes-agent.nixosModules.default
            inputs.sops-nix.nixosModules.sops
            ./hosts/desktop/hardware-configuration.nix
            ./hosts/desktop/nvidia.nix
            ./hosts/desktop/default.nix
            ./modules/secrets.nix
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

        # Work laptop (Sikt): Intel graphics, dual USB-C external monitors
        sikt = mkHost {
          hostName = "sikt";
          hostModules = [
            ./hosts/sikt/hardware-configuration.nix
            ./hosts/sikt/intel-graphics.nix
            ./hosts/sikt/default.nix
          ];
        };
      };
    };
}
