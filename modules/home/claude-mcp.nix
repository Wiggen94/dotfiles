# Declarative user-scope MCP servers for Claude Code.
#
# Both Claude Code instances read user-scope (a.k.a. "user" or "global") MCP
# servers from `$CLAUDE_CONFIG_DIR/.claude.json` → `mcpServers`:
#   - `claude`  (9Router-routed) uses the default dir, so ~/.claude.json
#   - `wclaude` (work account)   sets CLAUDE_CONFIG_DIR=~/.claude-work
#     (modules/system/packages.nix), so ~/.claude-work/.claude.json
#
# Declaring a server here lands it in both files on every host, so neither has to
# be configured by hand per machine, and `claude mcp add` is no longer how a
# server gets registered. A server can opt out of that fan-out with
# `configDirs` if it only makes sense on one instance (see nine-router-search).
#
# Why an activation instead of a Nix-managed file: .claude.json is not ours.
# Claude Code rewrites it constantly (oauthAccount, numStartups, the per-project
# history, changelogLastFetched…). A home.file would clobber all of that on the
# next rebuild, exactly the problem monitors.lua had before it became
# self-updating (CLAUDE.md). So we merge only the `mcpServers` entries we own
# and leave the rest of the document untouched.
#
# Removal is real, not append-only: the names we last wrote are recorded in
# ~/.local/state/nix-config/claude-mcp.json, and any name that disappears from
# `claudeMcpServers` is deleted from .claude.json on the next activation.
# Servers you added by hand (or via `claude mcp add`) are never touched.
{ config, lib, pkgs, ... }:
let
  cfg = config.claudeMcpServers;

  # The two config roots that must stay in sync. `wclaude` creates
  # ~/.claude-work itself (modules/system/packages.nix), but the activation
  # creates it here so the declarative servers are present on a fresh machine
  # *before* the first `wclaude` login — a stray empty dir on a host that never
  # uses the work account costs nothing.
  configDirs = [
    "$HOME"
    "$HOME/.claude-work"
  ];

  managedStatePath = "$HOME/.local/state/nix-config/claude-mcp.json";
in
{
  options.claudeMcpServers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          type = lib.mkOption {
            type = lib.types.str;
            default = "stdio";
            description = "Transport: stdio, http, sse or websocket.";
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = "Executable to launch (stdio transports).";
          };
          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Arguments passed to `command`.";
          };
          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Environment variables set for the server process.";
          };
          configDirs = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = ''
              Restrict this server to specific config roots (subset of the
              module's `configDirs`). Default null = register it everywhere.
              Needed for servers that are only meaningful on one instance —
              e.g. a 9Router-backed server, which must not reach `wclaude`.
            '';
            example = lib.literalExpression ''[ "$HOME" ]'';
          };
        };
      }
    );
    default = { };
    description = ''
      User-scope MCP servers to register for every Claude Code instance
      (`claude` and `wclaude`) on every host. Merged into each instance's
      `.claude.json` at activation; other content in that file is preserved.
    '';
    example = lib.literalExpression ''
      {
        codegraph = {
          command = "''${pkgs.codegraph}/bin/codegraph";
          args = [ "serve" "--mcp" ];
        };
      }
    '';
  };

  config =
    let
      # Per config root: the servers that belong in it. A server with
      # `configDirs = null` goes to every instance; a list restricts it.
      serversFor = dir:
        lib.mapAttrs (_: s: {
          inherit (s) type command args env;
        }) (lib.filterAttrs (_: s: s.configDirs == null || builtins.elem dir s.configDirs) cfg);

      serversJson = builtins.toJSON (lib.genAttrs configDirs serversFor);
    in
    {
      # The servers. Absolute store paths are required — Claude Code spawns
      # these itself, so the binary must not depend on the login shell's PATH.

      # Chrome DevTools for agents (pkgs/chrome-devtools-mcp) — the browser-driven
      # half of web development: console errors with source-mapped stacks, network
      # requests, performance traces and Core Web Vitals, post-hydration DOM, real
      # screenshots. None of that is possible with a crawler.
      #
      # It LAUNCHES a browser per session and tears it down on exit, so there is
      # no resident cost — nothing runs until a browser tool is called, and
      # nothing is left behind afterwards (verified: 0 processes after exit).
      # `--isolated` gives each session a throwaway profile, so sessions never
      # share cookies or contend over a profile lock.
      #
      # `pkgs.chromium.override { }` is not decoration: this config stubs
      # `pkgs.chromium` out with a script that exits 1 (modules/omarchy.nix), and
      # the stub carries `override` forwarding precisely so derivations that build
      # FROM chromium still work. Calling it steps past the stub to the real
      # Chromium 154. `pkgs.chromium` bare would hand the server a broken script
      # and every launch would fail.
      #
      # `--no-page-id-routing` (on by default upstream) makes every page-scoped
      # tool demand a pageId resolved through a roots/list round-trip. Off is the
      # plain single-page flow an agent session wants.
      #
      # Both telemetry switches are off: Google collects invocation stats by
      # default, and performance traces would otherwise send URLs to the CrUX API.
      claudeMcpServers.chrome-devtools = {
        command = "${pkgs.chrome-devtools-mcp}/bin/chrome-devtools-mcp";
        args = [
          "--executablePath"
          "${pkgs.chromium.override { }}/bin/chromium"
          "--headless"
          "--isolated"
          "--no-page-id-routing"
          "--no-usage-statistics"
          "--no-performance-crux"
        ];
      };

      # Code knowledge graph (github.com/colbymchenry/codegraph). Also on PATH
      # via modules/system/packages.nix for per-project `codegraph init`/`sync`.
      claudeMcpServers.codegraph = {
        command = "${pkgs.codegraph}/bin/codegraph";
        args = [ "serve" "--mcp" ];
      };

      # Live NixOS / Home Manager / nix-darwin / nixvim option and package
      # search, plus package version history. Purely local (packaged data
      # files), no network, no credentials.
      claudeMcpServers.mcp-nixos = {
        command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        args = [ ];
      };

      # GitHub MCP server. `command` is the auth wrapper, not the raw binary
      # (modules/system/nix.nix) — the server takes its token only via
      # GITHUB_PERSONAL_ACCESS_TOKEN, and the wrapper fills that from
      # `gh auth token`. Requires `gh auth login` to have been run.
      # --read-only drops the write tools.
      claudeMcpServers.github = {
        command = "${pkgs.github-mcp-server-auth}/bin/github-mcp-server-auth";
        args = [ "stdio" "--read-only" ];
      };

      # 9Router web search — replaces the built-in WebSearch tool, which cannot
      # work here: it asks Anthropic to run the search server-side, but requests
      # go through 9Router and never reach Anthropic (see
      # modules/home/claude-settings.nix, which also denies WebSearch/WebFetch).
      #
      # `claude`-only on purpose. Two reasons it must NOT reach wclaude:
      #   1. wclaude unsets ANTHROPIC_BASE_URL precisely so work traffic never
      #      touches the personal 9Router; this server would point back at it.
      #   2. wclaude talks to real Anthropic, where the built-in WebSearch does
      #      work — deniying it there would break a working tool.
      # The bearer key is not passed here: the server reads the sops secret
      # itself, so no credential ever lands in .claude.json.
      claudeMcpServers.nine-router-search = {
        command = "${pkgs.nine-router-search-mcp}/bin/9router-search-mcp";
        args = [ ];
        configDirs = [ "$HOME" ];
      };

      assertions = [
        {
          assertion = lib.all (s: s.command != "") (lib.attrValues cfg);
          message = "claudeMcpServers: every server needs a non-empty `command`.";
        }
      ];

      home.activation.claudeMcpServers =
        lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          ${pkgs.python3}/bin/python3 - ${lib.escapeShellArg serversJson} ${lib.escapeShellArg managedStatePath} <<'PYEOF'
          import json, os, sys

          # {config_root: {server_name: spec}} — the roots are the keys, so each
          # instance only receives the servers that belong to it.
          per_dir = json.loads(sys.argv[1])
          state_path = os.path.expandvars(sys.argv[2])

          # Every name this module has ever managed, across all roots. A server
          # that moves root (or is dropped entirely) is deleted from whichever
          # root still holds it, so removal is real rather than append-only.
          desired_all = set().union(*[set(v) for v in per_dir.values()]) if per_dir else set()
          try:
              managed = set(json.load(open(state_path)))
          except (FileNotFoundError, json.JSONDecodeError):
              managed = set()

          for raw_dir, servers in per_dir.items():
              d = os.path.expandvars(raw_dir)
              # The config dir itself may not exist yet — on a fresh machine
              # `wclaude` has never been run, so ~/.claude-work is absent and the
              # mkdir in its own script has not happened. Create it so the
              # declarative servers are already in place before the first login
              # (which is what the comment on `configDirs` promises).
              os.makedirs(d, exist_ok=True)
              path = os.path.join(d, ".claude.json")
              # A missing file just means that instance has not been launched
              # yet; create a minimal one so it starts with the declarative
              # servers already in place rather than waiting for a first run.
              try:
                  with open(path) as f:
                      doc = json.load(f)
              except FileNotFoundError:
                  doc = {}
              except json.JSONDecodeError:
                  print(f"nix-config: {path} is not valid JSON — MCP servers not merged")
                  continue

              current = doc.get("mcpServers", {})
              # Drop servers we managed on a previous generation but that no
              # longer belong in *this* root. User-added servers (absent from
              # `managed`) stay.
              for name in managed - set(servers):
                  if name in current:
                      del current[name]
              current.update(servers)
              doc["mcpServers"] = current

              with open(path, "w") as f:
                  json.dump(doc, f, indent=2)
                  f.write("\n")

          os.makedirs(os.path.dirname(state_path), exist_ok=True)
          with open(state_path, "w") as f:
              json.dump(sorted(desired_all), f)
          PYEOF
        '';
    };
}
