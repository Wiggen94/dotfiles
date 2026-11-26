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

    # Anthropic's official Linux .deb, repackaged; pinned to the signed apt
    # index and bumped hourly upstream. Replaced stslex/claude-desktop-linux
    # (macOS-DMG repack, archived 2026-07-07 once the official build shipped).
    # Deliberately NOT following nixpkgs: danielbodart.cachix.org (see
    # modules/system/nix.nix) only serves builds against the input's own
    # nixpkgs pin. Following ours rebuilds QEMU + libpipewire + the app locally.
    claude-desktop.url = "github:danielbodart/claude-desktop";

    # Zen browser. Unpinned: CI (nix-cache.yml) builds every lock update
    # before committing it, so a broken upstream bump never reaches main.
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium — Chromium-family browser: the default browser (mimeapps,
    # BROWSER) and the omarchy webapp launcher's --app= backend
    # (omarchy-launch-webapp); Zen stays installed as a second browser. Not in
    # nixpkgs — community flake, wraps imputnet's upstream .deb.
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ArtCraft "Crafting Apps" (PdfCraft, WordCraft, GridCraft, FigCraft,
    # DeckCraft, ...). Selected in modules/system/craftapps.nix.
    nix-craftapps = {
      url = "github:olafkfreund/nix-craftapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Omarchy 4 (quattro): quickshell-based shell + SDDM + zplug zsh, all
    # hosts. The user's Hyprland keybindings are kept via
    # modules/omarchy-hm.nix. home-manager follows is README-mandated.
    omarchy-nix = {
      url = "github:mrosseel/omarchy-nix/9d2ce961cc0c6454b793e5c977390fe0c7c957c1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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
        inputs.claude-desktop.nixosModules.default
        inputs.nix-craftapps.nixosModules.default
        ./modules/common.nix
        ./modules/omarchy.nix
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
            inputs.sops-nix.nixosModules.sops
            ./hosts/laptop/hardware-configuration.nix
            ./hosts/laptop/nvidia-prime.nix
            ./hosts/laptop/default.nix
            ./modules/secrets.nix
          ];
        };

        # Work laptop (Sikt): Intel graphics, dual USB-C external monitors
        sikt = mkHost {
          hostName = "sikt";
          hostModules = [
            inputs.sops-nix.nixosModules.sops
            ./hosts/sikt/hardware-configuration.nix
            ./hosts/sikt/intel-graphics.nix
            ./hosts/sikt/default.nix
            ./modules/secrets.nix
          ];
        };
      };
    };
}
