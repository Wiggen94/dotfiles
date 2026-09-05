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

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium — Chromium-family browser, used only by the omarchy webapp
    # launcher (omarchy-launch-webapp) to open PWAs as real --app= windows;
    # Zen (Firefox-based, no app mode) stays the daily browser. Not in
    # nixpkgs — community flake, wraps imputnet's upstream .deb.
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri: scrollable-tiling Wayland compositor, offered as an alternative
    # session alongside Hyprland (pick "Niri" at the SDDM greeter). Wiring is
    # in modules/system/niri.nix (system) and modules/home/niri.nix (config).
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Omarchy 4 (quattro): quickshell-based shell + SDDM + zplug zsh, all
    # hosts. The user's Hyprland keybindings are kept via
    # modules/omarchy-hm.nix. home-manager follows is README-mandated.
    omarchy-nix = {
      url = "github:mrosseel/omarchy-nix/bed862ec8c50cb12e658cefee0b63e938f8beaab";
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
        inputs.claude-cowork-service.nixosModules.default
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
