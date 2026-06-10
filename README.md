# Worktree Launcher

A small Bash wrapper that gives every Codex CLI task its own Git worktree and branch, without changing the command you type.

You still run:

```sh
codex
```

From the primary checkout of a repo, the wrapper asks for the task first:

```text
  Describe the task
› fix the broken login redirect when users sign in from Google
```

It turns the task into a worktree and branch, then starts the real Codex CLI inside it:

```text
codex-worktree: ~/repos/app-fix-broken-login-redirect on jesse/fix-broken-login-redirect
```

When the session ends, it offers to clean up after itself:

```text
› Clean up worktree ~/repos/app-fix-broken-login-redirect? [y/N] y
codex-worktree: removing ~/repos/app-fix-broken-login-redirect ...
codex-worktree: removed ~/repos/app-fix-broken-login-redirect
codex-worktree: deleted branch jesse/fix-broken-login-redirect
```

Each task gets an isolated checkout, so parallel Codex sessions never trip over each other and your main checkout stays clean. Press Enter on a blank prompt to run Codex in the current checkout instead.

## Why

Running coding agents in Git worktrees is the standard way to isolate parallel work, but the Codex CLI has no built-in flow for it on local checkouts. This wrapper adds the missing steps — create the worktree, start Codex inside it, offer to remove it afterwards — and nothing else. [docs/prior-art.md](docs/prior-art.md) covers the background.

## Requirements

- macOS or Linux with Bash 3.2+
- Git 2.5+ (the first version with `git worktree`)
- The Codex CLI somewhere on your `PATH`
- `python3`, only if you opt into Codex naming with `CODEX_WORKTREE_NAMER=codex`
- `expect`, only for running the test suite

## Install

```sh
git clone https://github.com/jesse-merhi/worktree-launcher.git ~/repos/worktree-launcher
cd ~/repos/worktree-launcher
./scripts/install.sh
```

Restart your shell, or run:

```sh
source ~/.zshrc
```

The installer copies:

```text
bin/codex-worktree -> ~/.local/bin/codex-worktree
```

and adds this shell alias if one is not already present:

```sh
alias codex='codex-worktree'
```

## Uninstall

```sh
cd ~/repos/worktree-launcher
./scripts/uninstall.sh
```

The uninstaller removes the installed wrapper and the managed shell block. If you wrote your own `codex` alias by hand, it is left alone and a warning is printed.

## When it stays out of the way

The wrapper only steps in for a fresh Codex session started from the primary checkout of a Git repo. Everything else goes straight to the real binary:

- subcommands that manage Codex itself: `resume`, `fork`, `doctor`, `cloud`, `app`, `update`, `cleanup`, `worktrees`, `login`, `mcp`, and friends
- explicit directory flags: `codex -C ...` and `codex --cd ...`
- `--help` and `--version`
- outside a Git repo
- already inside a linked worktree
- no task given: a blank interactive prompt, or a non-interactive shell with no arguments

## Branches and naming

The worktree is created next to your repo and the branch is `<prefix>/<slug>`:

```text
~/repos/app                          your checkout
~/repos/app-fix-broken-login-redirect    the task worktree
jesse/fix-broken-login-redirect          its branch
```

The prefix is the first word of your Git `user.name`, lowercased, falling back to `$USER`, then `codex`.

The slug comes from the task text. The default namer is local and instant: lowercase, drop filler words like `please`, `you`, `the`, and `when`, keep the first few meaningful words:

```text
Can you please fix the broken login redirect when users sign in from Google?
-> fix-broken-login-redirect
```

You can ask Codex to name the branch instead:

```sh
CODEX_WORKTREE_NAMER=codex codex "Fix login redirect"
```

That is opt-in because starting a second Codex agent just to name a worktree is noticeably slower. If it fails or times out, the local namer takes over.

New worktrees branch from the repo's default branch (`origin/HEAD`, falling back to `main`, then `master`). If the branch already exists, locally or on the remote, it is checked out instead of recreated.

## Cleanup

When the Codex session ends, the wrapper asks:

```text
› Clean up worktree ~/repos/app-fix-broken-login-redirect? [y/N]
```

Answering `y` removes the worktree with `git worktree remove` and deletes the branch when everything on it is already on the base branch.

Saying yes cannot lose work:

- Git refuses to remove a worktree with uncommitted or untracked files.
- A branch with its own commits is kept, and the exact `git branch -D` command to delete it deliberately is printed.

The default is no. Saying no keeps the worktree and prints the removal command for later. The prompt never appears in non-interactive shells, and `CODEX_WORKTREE_CLEANUP_PROMPT=0` disables it entirely.

There is no state file and no tracking: cleanup is a thin prompt over native `git worktree` commands.

## Configuration

Everything is an environment variable, so one-off overrides are just a prefix on the command.

| Variable | Default | Effect |
| --- | --- | --- |
| `CODEX_BIN` | first `codex` on `PATH` | Codex binary to launch |
| `CODEX_WORKTREE_NAMER` | `local` | `codex` asks Codex to name the branch |
| `CODEX_WORKTREE_NAMER_MODEL` | `gpt-5.1-codex` | Model used for Codex naming |
| `CODEX_WORKTREE_NAMER_TIMEOUT` | `8` | Seconds before Codex naming falls back to local |
| `CODEX_WORKTREE_SLUG` | derived from the task | Slug used in worktree and branch names |
| `CODEX_WORKTREE_BRANCH_PREFIX` | first word of Git `user.name` | Branch prefix in `<prefix>/<slug>` |
| `CODEX_WORKTREE_BRANCH` | `<prefix>/<slug>` | Full branch name |
| `CODEX_WORKTREE_DIR` | `../<repo>-<slug>` | Worktree path |
| `CODEX_WORKTREE_BASE` | repo default branch | Base branch for new worktrees |
| `CODEX_WORKTREE_FETCH` | `0` | `1` fetches the base branch before creating the worktree |
| `CODEX_WORKTREE_CLEANUP_PROMPT` | `1` | `0` skips the exit-time cleanup prompt |

Examples:

```sh
CODEX_WORKTREE_SLUG=login-redirect codex "Fix login redirect"
CODEX_WORKTREE_BASE=develop codex "Fix login redirect"
CODEX_WORKTREE_BRANCH_PREFIX=alice codex "Fix login redirect"
```

Fetch is off by default so the wrapper stays fast.

## Development

```sh
./scripts/test.sh
```

The tests syntax-check every script, then drive real worktree creation and the interactive prompts end to end in temp repos with temp home directories. `CODEX_BIN` points at `/bin/echo` or a small fake, so no real Codex session ever starts and your `~/.zshrc` is never touched.

[AGENTS.md](AGENTS.md) covers repo layout and the conventions for changes.

## Design notes

This is intentionally small. It is a launcher, not a session manager.

It cannot change the working directory of a running Codex TUI session. It creates the worktree first, then starts the real CLI with `-C`.
