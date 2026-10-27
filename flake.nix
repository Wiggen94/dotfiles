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

    # Zen browser. Rev-pinned deliberately: upstream's auto-updater bumped
    # sources.json to 1.23.3b (commit 7efaabec, 2026-10-16) eight hours BEFORE
    # that release's assets were published, so the declared hash matches
    # nothing and the build fails with a fixed-output hash mismatch. Pinning
    # the last good rev (458cd161 = 1.23.2b) keeps both local `nfu` and CI
    # working. Unpin — drop the /<rev> suffix — once upstream fixes it
    # (zen-browser-flake issues #22/#23) or ships 1.23.4b.
    zen-browser = {
      url = "github:youwen5/zen-browser-flake/458cd16116c362a5e92d5db6bdc3599e4e8b1f4a";
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
      url = "github:mrosseel/omarchy-nix/cceda1dd28d08c68154adef98f1cd01d3411bc2a";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      # Upstream pins quickshell v0.3.1, which does not compile against qtbase
      # 6.12: its MOC data carries opaque-pointer definitions and 6.12 rejects
      # incomplete types in a QMetaType conversion ("Meta Types must be fully
      # defined"). 0.3.2 fixes it (quickshell@5d5d498). Drop this override once
      # omarchy-nix bumps its own pin. See modules/home/omarchy-qt612.nix.
      inputs.quickshell.url = "github:quickshell-mirror/quickshell/v0.3.2";
      # Overriding the URL alone drops the follows omarchy-nix declared, which
      # would build quickshell against quickshell's own pinned nixpkgs instead
      # of ours (different Qt — exactly the mismatch this override exists to
      # avoid). Re-state it.
      inputs.quickshell.inputs.nixpkgs.follows = "nixpkgs";
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
