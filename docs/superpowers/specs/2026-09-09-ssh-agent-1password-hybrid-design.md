# SSH agent: drop 1Password's agent socket, keep 1Password as key vault

**Date:** 2026-09-09
**Status:** Design approved, pending spec review

## Goal

1Password's own SSH agent (`~/.1password/agent.sock`, wired up as the global
`SSH_AUTH_SOCK` and as `IdentityAgent` for `Host *` in `~/.ssh/config`) locks
itself in ways that break `git push` / `ssh` mid-session, and 1Password's
Linux build exposes no "lock after X minutes" control in its Settings UI to
loosen this (confirmed by inspection — see "Investigation notes" below).

Fix: keep the actual SSH private keys stored in 1Password (still the source
of truth — easy to view/rotate/audit from any device), but stop depending on
1Password's own agent process and its lock timer at SSH-use time. Instead,
pull the keys out via the `op` CLI once per login session and hand them to a
plain, native `ssh-agent` that 1Password can no longer interfere with. The
native agent (and the decrypted keys in it) lives only in that session's
memory and disappears naturally at logout/shutdown/reboot.

## Investigation notes (why this shape, not something else)

- `op signin` shares 1Password's own unlock/auth state with the desktop app
  (`developers.cliSharedLockState.enabled: true` is already set in
  `~/.config/1Password/settings/settings.json`) — confirmed working
  end-to-end: running it triggers the system-auth prompt, and afterwards
  `ssh-add -l` / `git push` work without a further prompt.
- `~/.config/1Password/settings/settings.json` carries an `authTags` map — an
  integrity signature per key. Hand-editing this file (e.g. via Home Manager
  `home.file`) to raise `security.autolock.minutes` risks 1Password detecting
  tampering and resetting the file (possibly all settings, not just the lock
  timeout). Not attempted; ruled out as a fix.
- The 1Password 8 Linux Settings UI has no exposed "Auto-Lock" / "lock after
  X minutes of inactivity" control (confirmed by the user directly in-app),
  so there's no safe supported way to loosen the timer either.
- The `1password` binary has a `--lock` flag but no `--unlock` flag — no
  direct CLI unlock of the app itself either.
- The Personal vault holds three `SSH Key` items (`id_rsa`, `Gjermund`,
  `stamnett-git-mirror`) used across different remotes (GitHub, GitLab, a
  git mirror). Rather than map each to a specific host/remote, the unlock
  script loads all of them, matching how 1Password's own agent already
  exposes every enabled key to any ssh client.

## Architecture

Three pieces, all in this repo.

### 1. Native per-session ssh-agent (`modules/system/users.nix`)

```nix
programs.ssh.startAgent = true;
```

This is NixOS's built-in agent (`nixos/modules/programs/ssh.nix`): a
`systemd --user` service `ssh-agent.service`, `wantedBy = [ "default.target" ]`,
listening on `$XDG_RUNTIME_DIR/ssh-agent`, `Restart = "on-failure"`, no
`agentTimeout` set (so loaded keys never expire on their own — the agent
process itself is what goes away, at logout). `environment.extraInit` sets
`SSH_AUTH_SOCK` to that socket automatically for every login shell, if unset.

Remove the old override:
```nix
# was: SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
```
from `environment.sessionVariables` in the same file.

### 2. `ssh-key-unlock` script (`modules/system/packages.nix`)

New `pkgs.writeShellScriptBin "ssh-key-unlock"`, following the existing
script conventions in this file (`${pkgs.X}/bin/Y` refs, `notify-send` for
user-visible feedback, no assumption of a TTY since it's autostarted):

- Retries `op signin` for ~30s (it can race 1Password's own autostart at
  session start) before giving up and notifying failure.
- On success, lists every `SSH Key`-category item in the `Personal` vault
  (`op item list --categories "SSH Key" --vault Personal --format json`),
  and for each: `op read "op://Personal/<id>/private key?ssh-format=openssh" | ssh-add -`.
- `notify-send`s a success summary (count of keys loaded) or a failure
  reason.
- Safe to re-run manually mid-session (e.g. after the native agent was
  somehow restarted) — `ssh-add` on an already-loaded key is a harmless
  no-op/duplicate.

### 3. Autostart wiring

Alongside the existing 1Password autostart entry, so `ssh-key-unlock` starts
right after 1Password does each login:

- `modules/home/_common.nix` (Hyprland Lua): add `hl.exec_cmd("ssh-key-unlock")`
  immediately after the existing `hl.exec_cmd("1password")`.
- `modules/home/niri.nix` intentionally **not** touched — niri is a secondary
  session (may be removed from this repo entirely) and this fix targets the
  Hyprland session this host actually runs.

### 4. `ssh` client config (`modules/home/programs.nix`)

Remove `IdentityAgent = "~/.1password/agent.sock";` from the `Host *` block
so `ssh` falls back to `SSH_AUTH_SOCK` (now the native agent) by default.

## What stays unchanged

- `k3s`/`k3s.lan` host block: already `IdentityAgent = "none"` with an
  on-disk `~/.ssh/id_ed25519` — untouched, was never part of the problem.
- Git commit signing: `programs.git.extraConfig.gpg.ssh.program = op-ssh-sign`
  (`modules/home/programs.nix`) still talks to 1Password directly at commit
  time, independent of the ssh-agent change. It incidentally benefits from
  the same `op signin` shared-lock-state already confirmed working.
- 1Password's own `sshAgent.enabled` setting and `~/.1password/agent.sock`
  are left alone (not disabled) — per the `authTags` tamper-protection
  finding above, `settings.json` isn't touched at all. The socket just goes
  unused since nothing points `SSH_AUTH_SOCK`/`IdentityAgent` at it anymore.

## Error handling

- `ssh-key-unlock` failing (signin timeout/cancelled, network down, no items
  found) must not crash or block session startup — it's a background
  autostart command; failure surfaces only via `notify-send`, and the user
  can re-run it manually once the underlying issue is fixed.
- If the native `ssh-agent.service` unit itself dies mid-session
  (`Restart = "on-failure"` handles crashes), a fresh empty agent comes back
  on the same socket path but with no keys loaded — `ssh-key-unlock` must be
  re-run manually in that case. Not automated further; this is an edge case,
  not the common path.

## Testing plan

- After `nrs`: confirm `systemctl --user status ssh-agent` is active, `echo
  $SSH_AUTH_SOCK` points at `$XDG_RUNTIME_DIR/ssh-agent`, and `ssh-key-unlock`
  run manually prompts once and leaves `ssh-add -l` showing 3 keys.
  A real `git push` (this repo) should succeed with no further prompt.
- Reboot and confirm autostart fires `ssh-key-unlock` without manual
  intervention (one prompt at login), and `k3s.lan` ssh access is unaffected.
- Confirm git commit signing still works (`git commit` on this repo, check
  signature) — should be untouched but worth a smoke test since it also
  goes through `op`.
