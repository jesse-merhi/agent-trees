# Agent Guide

Orientation for AI agents and new contributors.

## What this is

One Bash script that wraps the Codex CLI. When you run `codex` with a task
prompt from the primary checkout of a Git repo, it creates a task-specific
Git worktree and branch, then runs the real Codex binary with
`-C <worktree>`. When the session ends it offers to remove the worktree.
Everything else passes through untouched via `exec`.

## Layout

| Path | Purpose |
| --- | --- |
| `bin/codex-worktree` | The whole program. Plain Bash. |
| `scripts/install.sh` | Copies the script to `~/.local/bin` and adds a managed alias block to `~/.zshrc`. |
| `scripts/uninstall.sh` | Removes the installed script and the managed alias block. |
| `scripts/test.sh` | The full test suite. |
| `docs/prior-art.md` | Why this exists and what others do instead. |

## Test

```sh
./scripts/test.sh
```

This syntax-checks every script, then runs end-to-end tests in temp Git
repos with temp home directories. `CODEX_BIN` points at `/bin/echo` or a
fake binary, so no real Codex session ever starts and your real `~/.zshrc`
is never touched. `expect` must be installed for the interactive-prompt
test.

## Conventions

- Stay compatible with Bash 3.2 (the macOS default). No `${var,,}`, no
  associative arrays, no `mapfile`.
- No runtime dependencies beyond Git and standard Unix tools. `python3` is
  allowed only in the opt-in Codex naming path, and the script must still
  work without it.
- Every behavior change gets a matching case in `scripts/test.sh`.
- User-facing configuration is environment variables prefixed
  `CODEX_WORKTREE_`. Document new ones in `README.md`.
- This is a launcher, not a session manager. Do not add state files,
  cleanup daemons, or worktree tracking. Cleanup is an exit-time prompt
  that runs native `git worktree remove` and nothing more (see
  `docs/prior-art.md`).
- The interactive prompts deliberately mimic the Codex TUI: a grey
  `48;5;236` band, a dim `›` caret on the band edge, and text starting at
  column 3. Compare against a real Codex session before restyling them.
