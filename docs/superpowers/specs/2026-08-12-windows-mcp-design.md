# Windows MCP — Claude Code control of the Windows VM

**Date:** 2026-08-12
**Host:** `desktop` only

## Goal

Give Claude Code (running on the Linux host) full control of the Windows 11 VM —
file operations, app control, system management, UI automation — via
[Windows-MCP](https://github.com/CursorTouch/Windows-MCP).

First task after setup: use the MCP server to debloat the VM.

## Architecture

```
┌──────────────────────────────────────────────────┐
│ Linux Host (desktop)                             │
│                                                  │
│  Claude Code                                     │
│    │                                             │
│    │ MCP (streamable-http)                       │
│    ▼                                             │
│  192.168.122.100:8000/mcp                        │
│    │                                             │
│    │ virbr0 (libvirt default NAT, already up)    │
│    ▼                                             │
├──────────────────────────────────────────────────┤
│ Windows 11 VM                                    │
│                                                  │
│  windows-mcp serve                               │
│  --transport streamable-http                     │
│  --port 8000                                     │
│  --auth-key "<token>"                            │
│    │                                             │
│    ▼                                             │
│  Python 3.13+ + uv + UIA backend                 │
│  (Click, Type, PowerShell, FileSystem, etc.)     │
└──────────────────────────────────────────────────┘
```

No port forwarding needed — the host already reaches the guest over `virbr0`.
A libvirt DHCP reservation pins the guest IP so the MCP URL doesn't drift.

## Windows-side setup (manual, one-time)

### 1. Install Python 3.13+

Download from <https://python.org> or run:
```
winget install python3
```

### 2. Install uv

```powershell
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### 3. First run (pulls dependencies)

```
uvx windows-mcp serve
```

First run takes a minute or two installing dependencies. Kill it once it starts.

### 4. Generate auth key

```
uvx windows-mcp auth
```

This writes a config file plus a bearer token to `~/.windows-mcp/config.toml`.
Save the token for the Linux-side MCP config.

### 5. Install as auto-start Scheduled Task

```
windows-mcp install --transport streamable-http --port 8000 --auth-key "<token>"
```

Creates a per-user Scheduled Task named `windows-mcp-server` that runs at login.
Logs go to `~/.windows-mcp/server.log` and `server.error.log`.

## Host-side setup

### libvirt DHCP reservation

Reserve a fixed IP for the VM's MAC address on the default NAT network so the
MCP URL never drifts:

```bash
virsh net-update default add ip-dhcp-host \
  "<host mac='52:54:00:xx:xx:xx' name='win11' ip='192.168.122.100'/>" --live --config
```

(The MAC is whatever `virsh dumpxml win11 | grep 'mac address'` shows.)

### Claude Code MCP config

Add to `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "windows-vm": {
      "type": "streamable-http",
      "url": "http://192.168.122.100:8000/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```

## Validation

1. Boot the VM, verify the Scheduled Task starts: check `~/.windows-mcp/server.log` for "listening"
2. From the host: `curl -H "Authorization: Bearer <token>" http://192.168.122.100:8000/mcp` — should return an MCP endpoint response
3. In Claude Code: MCP tools (`Click`, `PowerShell`, `FileSystem`, etc.) should appear
4. Smoke test: `PowerShell: Write-Host "hello from MCP"`
5. First real task: debloat the VM

## Security notes

- Auth key is required — without it anyone on `virbr0` could control the VM
- The token lives in `~/.claude/mcp.json` (0600 permissions)
- `virbr0` is host-only NAT, not exposed to the LAN
- No TLS needed since the connection never leaves the host
- `--tools` whitelist available if we ever want to restrict what Claude can do

## Out of scope

- Making any of this declarative in Nix (the VM is imperatively managed)
- Adding the MCP config to nix-managed dotfiles
- Supporting `laptop` or `sikt` hosts
