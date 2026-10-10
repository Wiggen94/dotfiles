#!/usr/bin/env python3
"""stdio MCP server exposing 9Router web search.

Why this exists: Claude Code's built-in WebSearch/WebFetch ask *Anthropic* to run
a server-side search and return `web_search_tool_result` blocks. Every request
here goes through 9Router, whose `cc/*` tier 401s (no Claude subscription on this
account), so requests never reach Anthropic -- they land on an Ollama fallback
leg that accepts the `web_search_20250305` tool declaration but cannot execute
it, returning `tool_use` with `input: {}`. So the built-ins are unusable here and
are denied in settings.json; this server replaces them.

9Router exposes search as plain REST (POST /v1/search). This speaks the MCP
stdio transport (newline-delimited JSON-RPC 2.0) so Claude Code can call it as a
normal tool.

Auth: the bearer key is the sops secret /run/secrets/9router_api_key, read at
call time. It is deliberately NOT passed via the MCP server's env -- that env
lands in ~/.claude.json, which is not a secret store.

Nothing may be written to stdout except JSON-RPC; diagnostics go to stderr.
"""

import json
import os
import sys
import urllib.error
import urllib.request

PROTOCOL_VERSIONS = ("2025-06-18", "2025-03-26", "2024-11-05")
DEFAULT_PROTOCOL = "2024-11-05"

BASE_URL = os.environ.get("NINEROUTER_URL", "http://192.168.0.182:20128")
KEY_FILE = os.environ.get("NINEROUTER_KEY_FILE", "/run/secrets/9router_api_key")
DEFAULT_MODEL = os.environ.get("NINEROUTER_SEARCH_MODEL", "search-combo")

# The ollama-search leg returns the fetched page body as `snippet`, not a short
# summary, so a naive dump of 5 results can be tens of thousands of characters.
# Cap per result: enough to answer from, bounded enough not to flood context.
SNIPPET_CHARS = 1500


def log(msg):
    print(f"9router-search-mcp: {msg}", file=sys.stderr, flush=True)


def read_key():
    try:
        with open(KEY_FILE) as f:
            key = f.read().strip()
    except OSError as e:
        raise RuntimeError(f"cannot read {KEY_FILE}: {e}") from e
    if not key:
        raise RuntimeError(f"{KEY_FILE} is empty")
    return key


def search(query, max_results, search_type):
    body = {"model": DEFAULT_MODEL, "query": query, "max_results": max_results}
    if search_type and search_type != "web":
        body["search_type"] = search_type

    req = urllib.request.Request(
        f"{BASE_URL.rstrip('/')}/v1/search",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {read_key()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    # Search hits upstream providers (Ollama, Brave) and can be slow; the earlier
    # curl calls to this endpoint took up to ~30s on a cold provider.
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read().decode())


def format_results(payload):
    results = payload.get("results") or []
    if not results:
        return "No results."

    provider = payload.get("provider") or "unknown"
    out = [f"{len(results)} result(s) via {provider}:"]
    for i, r in enumerate(results, 1):
        title = (r.get("title") or "").strip()
        url = (r.get("url") or "").strip()
        snippet = (r.get("snippet") or "").strip()
        if len(snippet) > SNIPPET_CHARS:
            snippet = snippet[:SNIPPET_CHARS] + " …[truncated]"
        out.append(f"\n[{i}] {title}\n{url}\n{snippet}")
    return "\n".join(out)


def call_tool(name, args):
    if name != "web_search":
        raise RuntimeError(f"unknown tool: {name}")

    query = (args.get("query") or "").strip()
    if not query:
        raise RuntimeError("`query` is required")

    max_results = args.get("max_results") or 5
    try:
        max_results = max(1, min(int(max_results), 10))
    except (TypeError, ValueError):
        raise RuntimeError("`max_results` must be an integer")

    search_type = args.get("search_type") or "web"

    try:
        payload = search(query, max_results, search_type)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        raise RuntimeError(f"9Router returned HTTP {e.code}: {detail}") from e
    except urllib.error.URLError as e:
        raise RuntimeError(f"cannot reach 9Router at {BASE_URL}: {e.reason}") from e

    return format_results(payload)


TOOLS = [
    {
        "name": "web_search",
        "description": (
            "Search the web and get back result titles, URLs and page text. "
            "Use this for anything needing current information: docs, releases, "
            "news, facts, error messages, library versions. "
            "This replaces the built-in WebSearch tool, which does not work on "
            "this setup (it asks Anthropic to run the search server-side, and "
            "requests here are served by a non-Anthropic fallback that cannot "
            "execute it). Always prefer this tool over WebSearch or WebFetch. "
            "Returns full page text, so results can often answer the question "
            "without fetching the URL separately; web fetch is not available."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query.",
                },
                "max_results": {
                    "type": "integer",
                    "description": "How many results to return (1-10, default 5).",
                },
                "search_type": {
                    "type": "string",
                    "enum": ["web", "news"],
                    "description": "Result type. Defaults to web.",
                },
            },
            "required": ["query"],
        },
    }
]


def handle(req):
    method = req.get("method")
    req_id = req.get("id")

    # Notifications (no id) must not be answered.
    if req_id is None:
        return None

    if method == "initialize":
        asked = (req.get("params") or {}).get("protocolVersion")
        version = asked if asked in PROTOCOL_VERSIONS else DEFAULT_PROTOCOL
        return {
            "protocolVersion": version,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "9router-search", "version": "1.0.0"},
        }

    if method == "ping":
        return {}

    if method == "tools/list":
        return {"tools": TOOLS}

    if method == "tools/call":
        params = req.get("params") or {}
        try:
            text = call_tool(params.get("name"), params.get("arguments") or {})
        except Exception as e:  # surfaced to the model, not fatal to the session
            log(f"tools/call failed: {e}")
            return {
                "content": [{"type": "text", "text": f"Error: {e}"}],
                "isError": True,
            }
        return {"content": [{"type": "text", "text": text}]}

    return None


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            log(f"ignoring non-JSON input: {line[:200]}")
            continue

        try:
            result = handle(req)
        except Exception as e:
            log(f"handler error for {req.get('method')}: {e}")
            if req.get("id") is not None:
                out = {
                    "jsonrpc": "2.0",
                    "id": req["id"],
                    "error": {"code": -32603, "message": str(e)},
                }
                print(json.dumps(out), flush=True)
            continue

        if result is None and not str(req.get("method", "")).startswith("notifications/"):
            # Unknown request (not a notification): answer per JSON-RPC so the
            # client is not left waiting.
            if req.get("id") is not None and req.get("method") not in (
                "initialized",
                "notifications/initialized",
            ):
                out = {
                    "jsonrpc": "2.0",
                    "id": req["id"],
                    "error": {"code": -32601, "message": f"method not found: {req.get('method')}"},
                }
                print(json.dumps(out), flush=True)
            continue

        if result is not None:
            print(json.dumps({"jsonrpc": "2.0", "id": req["id"], "result": result}), flush=True)


if __name__ == "__main__":
    main()
