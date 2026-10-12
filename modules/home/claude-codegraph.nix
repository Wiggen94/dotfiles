# Auto-initialise codegraph in every git repo a Claude Code session starts in.
#
# The codegraph MCP server (modules/home/claude-mcp.nix) is registered
# everywhere, but it only has something to answer with once the project has
# been indexed by `codegraph init` — which is easy to forget. This adds a
# SessionStart hook to both instances (`claude` and `wclaude`) that does it on
# first contact:
#
#   - resolves the session's cwd to its git toplevel (no repo → nothing to do,
#     so scratch dirs and $HOME are never indexed)
#   - skips repos that already have .codegraph/codegraph.db
#   - skips very large repos (> MAX_FILES tracked files) — indexing a nixpkgs
#     checkout behind your back is not what anyone wants; init those by hand
#   - otherwise runs `codegraph init -y` DETACHED, so the session never waits
#     on indexing, under a per-repo flock so two sessions starting in the same
#     repo don't index it twice. Log: ~/.local/state/codegraph-auto-init/.
#
# `init` only creates .codegraph/, which ships its own .gitignore that ignores
# everything but itself — so the one visible effect in a repo is an untracked
# .codegraph/.gitignore (commit it, as this repo did, or ignore it).
#
# The first session in a fresh repo may not see the index until indexing
# finishes; later sessions do.
#
# Same ownership model as claude-settings.nix: settings.json is not ours, so
# the activation merges only the one hook entry it owns (identified by the
# script name in its command) and leaves every other hook untouched.
{ config, lib, pkgs, ... }:
let
  autoInit = pkgs.writeShellApplication {
    name = "codegraph-auto-init";
    runtimeInputs = [ pkgs.codegraph pkgs.git pkgs.jq pkgs.util-linux pkgs.coreutils ];
    text = ''
      MAX_FILES=20000
      cwd=$(jq -r '.cwd // empty' 2>/dev/null || true)
      [ -n "$cwd" ] || cwd=$PWD

      root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
      [ "$root" != "$HOME" ] || exit 0
      [ ! -e "$root/.codegraph/codegraph.db" ] || exit 0

      files=$(git -C "$root" ls-files | wc -l)
      if [ "$files" -gt "$MAX_FILES" ]; then
        echo "codegraph: $root not indexed ($files tracked files > $MAX_FILES). Run \`codegraph init\` there by hand if wanted."
        exit 0
      fi

      state="$HOME/.local/state/codegraph-auto-init"
      mkdir -p "$state"
      key=$(printf '%s' "$root" | sha256sum | cut -c1-16)
      setsid -f flock -n "$state/$key.lock" \
        codegraph init -y "$root" >"$state/$key.log" 2>&1 </dev/null
      echo "codegraph: first-time indexing of $root started in the background ($files files); codegraph tools work once it finishes."
    '';
  };

  configDirs = [ "$HOME/.claude" "$HOME/.claude-work" ];
in
{
  home.activation.claudeCodegraphAutoInit =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${pkgs.python3}/bin/python3 - ${lib.escapeShellArg "${autoInit}/bin/codegraph-auto-init"} ${lib.escapeShellArgs configDirs} <<'PYEOF'
      import json, os, sys

      command, dirs = sys.argv[1], sys.argv[2:]
      MARK = "codegraph-auto-init"
      entry = {
          "matcher": "startup",
          "hooks": [{"type": "command", "command": command, "timeout": 15}],
      }

      def ours(group):
          return any(MARK in h.get("command", "") for h in group.get("hooks", []))

      for raw in dirs:
          d = os.path.expandvars(raw)
          os.makedirs(d, exist_ok=True)
          path = os.path.join(d, "settings.json")
          try:
              with open(path) as f:
                  s = json.load(f)
          except FileNotFoundError:
              s = {}
          except json.JSONDecodeError:
              print(f"nix-config: {path} is not valid JSON — codegraph hook not merged")
              continue

          hooks = s.setdefault("hooks", {})
          groups = [g for g in hooks.get("SessionStart", []) if not ours(g)] + [entry]
          if hooks.get("SessionStart") != groups:
              hooks["SessionStart"] = groups
              with open(path, "w") as f:
                  json.dump(s, f, indent=2)
                  f.write("\n")
              print(f"nix-config: codegraph auto-init hook set in {path}")
      PYEOF
    '';
}
