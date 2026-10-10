# MCP server for 9Router web search (pkgs/9router-search-mcp).
#
# Wraps the stdio MCP server in a shell script with an absolute python3, because
# Claude Code spawns MCP servers itself and they must not depend on the login
# shell's PATH. See the script's own docstring for why the built-in WebSearch
# tool is unusable here and this replaces it.
{
  writeShellApplication,
  python3,
}:

writeShellApplication {
  name = "9router-search-mcp";
  runtimeInputs = [ python3 ];
  text = ''
    exec python3 ${../../modules/home/mcp/9router-search-server.py} "$@"
  '';
}
