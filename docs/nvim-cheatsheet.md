# Neovim Cheat Sheet

For the nixvim config in `modules/system/neovim.nix`. Generated 2026-08-15.

**Forgot a key?** `:Telescope keymaps` — fuzzy-search every hotkey by key *or* description (e.g. type "diagnostic" and find them all). `:Telescope commands` does the same for commands.

**Leader** = `Space`.

## Diagnostics (inline — shown right in the buffer)

Errors render as inline text after the offending line, with a red squiggle and gutter sign. No panels needed.

| Key | Action |
|-----|--------|
| `ge` | Popup with full error message (under cursor) |
| `Space dn` | Next diagnostic |
| `Space dp` | Previous diagnostic |
| `Space xx` | Trouble panel — list of all diagnostics |
| `]d` / `[d` | Built-in next/prev (awkward on Norwegian layout — use `Space dn/dp`) |

## LSP

| Key | Action |
|-----|--------|
| `K` | Hover docs |
| `gd` | Go to definition |
| `gs` | Signature help |
| `gO` | Document symbols |
| `grt` | Type definition |
| `gri` | Implementation |
| `grr` | References |
| `grn` | Rename |
| `gra` | Code action (the lightbulb) |
| `grx` | Run code lens |

| Command | Action |
|---------|--------|
| `:LspInfo` | Shows which language server is attached |
| `:checkhealth lsp` | Health check for the LSP plugin |
| `:LspLog` | Server logs (why did it fail to start?) |

Language servers: `rust-analyzer` (.rs — needs a Cargo project), `nixd` (.nix), `lua_ls` (.lua), `pyright` (.py), `ts_ls` (.ts/.js).

## Leader (Space) keymaps

| Key | Action |
|-----|--------|
| `Space e` | Toggle file explorer (Neotree) |
| `Space ff` | Find files |
| `Space fg` | Live grep |
| `Space fb` | Buffers |
| `Space fh` | Help tags |
| `Space gg` | LazyGit |
| `Space bd` | Delete buffer |
| `Space xx` | Trouble diagnostics |
| `Space dn` | Next diagnostic |
| `Space dp` | Previous diagnostic |
| `Space cs` | Open this cheat sheet |

## Buffers

| Key | Action |
|-----|--------|
| `Shift+l` | Next buffer |
| `Shift+h` | Previous buffer |

## Find-anything (Telescope)

| Command | Finds |
|---------|-------|
| `:Telescope keymaps` | All hotkeys (key or description) |
| `:Telescope commands` | All commands |
| `:Telescope builtin` | All pickers |
| `:Telescope diagnostics` | All errors/warnings |
| `:Telescope help_tags` | Vim help |
| `:Telescope live_grep` | Text in files |

## Norwegian layout notes

- Every custom hotkey uses keys that exist as plain characters on the Norwegian layout — no brackets, no AltGr.
- The built-in `]d`/`[d` (brackets need AltGr on NO layout) are superseded by `Space dn/dp`.
- Optionally, for full bracket motions (`[`, `]`, `{`, `}` in normal mode), add a `langmap` so `å` → `[`, `ø` → `]` etc. — ask in a future session if the brackets still annoy you.
