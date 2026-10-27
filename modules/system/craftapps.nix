# ArtCraft "Crafting Apps" from the nix-craftapps flake input. Each app
# installs a GUI (`pdfcraft`) plus a CLI companion (`pdfcraft-cli`).
# linkFonts (on by default) links /usr/share/fonts, which the apps' text
# tools read directly instead of going through fontconfig.
{ config, lib, ... }:
{
  programs.craftapps = {
    enable = true;
    # Defines one stdio MCP server per enabled app (`<app>-cli mcp`), with
    # upstream's per-app args (e.g. `--compact` for pdfcraft).
    mcp.enable = true;
    apps = {
      pdfcraft.enable = true;
      wordcraft.enable = true;
      gridcraft.enable = true;
      figcraft.enable = true;
      deckcraft.enable = true;
    };
  };

  # Register those servers for both claude and wclaude via the declarative
  # claudeMcpServers merge (modules/home/claude-mcp.nix). Fully local, so no
  # configDirs restriction. Enabling another app above registers it too.
  home-manager.users.gjermund.claudeMcpServers = lib.mapAttrs (_: s: {
    inherit (s) command args;
  }) config.programs.craftapps.mcp.servers;
}
