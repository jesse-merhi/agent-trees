# sidegrove

A small Bash wrapper that gives every coding-agent task its own Git worktree and branch, without changing the commands you type. Works with Codex CLI, Claude Code, and any similar CLI.

You still run:

```sh
claude
```

From the primary checkout of a repo, the wrapper asks for the task first:

```text
  Describe the task
› fix the broken login redirect when users sign in from Google
```

It turns the task into a worktree and branch, then starts the real CLI inside it:

```text
sidegrove: ~/repos/app-fix-broken-login-redirect on jesse/fix-broken-login-redirect
```

When the session ends, it offers to clean up after itself:

```text
› Clean up worktree ~/repos/app-fix-broken-login-redirect? [y/N] y
sidegrove: removing ~/repos/app-fix-broken-login-redirect ...
sidegrove: removed ~/repos/app-fix-broken-login-redirect
sidegrove: deleted branch jesse/fix-broken-login-redirect
```

Each task gets an isolated checkout, so parallel agent sessions never trip over each other and your main checkout stays clean. Press Enter on a blank prompt to run in the current checkout instead.

## Why

Running coding agents in Git worktrees is the standard way to isolate parallel work, but doing it by hand means naming a branch, creating the worktree, starting the agent there, and remembering to remove it later. sidegrove folds all of that into the command you already type, with the same flow for every CLI. [docs/prior-art.md](docs/prior-art.md) covers the background.

## Supported CLIs

The wrapper is one binary invoked as `sidegrove <cli>`:

```sh
sidegrove codex "Fix login redirect"
sidegrove claude "Fix login redirect"
```

`codex` and `claude` get tailored handling: their value-taking flags are understood when extracting the task from arguments, their management subcommands (`mcp`, `doctor`, `update`, ...) pass through, and their resume flows (`codex resume`, `claude -c` / `-r`) never create worktrees. For Claude Code, `-p` print mode and the built-in `-w` worktree flag also pass through untouched.

Any other CLI works with safe generic defaults:

```sh
alias mycli='sidegrove mycli'
```

## Requirements

- macOS or Linux with Bash 3.2+
- Git 2.5+ (the first version with `git worktree`)
- The agent CLIs you use somewhere on your `PATH`
- `python3`, only if you opt into agent naming with `SIDEGROVE_NAMER=agent`
- `expect`, only for running the test suite

## Install

```sh
git clone https://github.com/jesse-merhi/sidegrove.git ~/repos/sidegrove
cd ~/repos/sidegrove
./scripts/install.sh
```

Restart your shell, or run:

```sh
source ~/.zshrc
```

The installer copies:

```text
bin/sidegrove -> ~/.local/bin/sidegrove
```

and adds a managed alias block to `~/.zshrc`:

```sh
alias codex='sidegrove codex'
alias claude='sidegrove claude'
```

Each alias is guarded by a `command -v` check, so nothing breaks if one of the CLIs is not installed. Aliases you wrote yourself are detected and left alone. Installing over an old `worktree-launcher` setup migrates it automatically.

## Uninstall

```sh
cd ~/repos/sidegrove
./scripts/uninstall.sh
```

The uninstaller removes the installed wrapper and the managed shell block.

## When it stays out of the way

The wrapper only steps in for a fresh session started from the primary checkout of a Git repo. Everything else goes straight to the real binary:

- management subcommands (`mcp`, `doctor`, `update`, `login`, ...)
- resume and continue flows (`codex resume`, `claude -c`, `claude -r`)
- `claude -p` print mode and `claude -w` native worktrees
- explicit directory flags (`codex -C ...`)
- `--help` and `--version`
- outside a Git repo
- already inside a linked worktree
- no task given: a blank interactive prompt, or a non-interactive shell with no arguments

## Branches and naming

The worktree is created next to your repo and the branch is `<prefix>/<slug>`:

```text
~/repos/app                              your checkout
~/repos/app-fix-broken-login-redirect    the task worktree
jesse/fix-broken-login-redirect          its branch
```

The prefix is the first word of your Git `user.name`, lowercased, falling back to `$USER`, then `agent`.

The slug comes from the task text. The default namer is local and instant: lowercase, drop filler words like `please`, `you`, `the`, and `when`, keep the first few meaningful words:

```text
Can you please fix the broken login redirect when users sign in from Google?
-> fix-broken-login-redirect
```

You can ask the agent itself to name the branch instead:

```sh
SIDEGROVE_NAMER=agent claude "Fix login redirect"
```

For Codex this runs a tiny `codex exec` call; for Claude Code a `claude -p` call with a fast model. It is opt-in because spinning up a second agent just to name a worktree adds a few seconds. If it fails or times out, the local namer takes over.

New worktrees branch from the repo's default branch (`origin/HEAD`, falling back to `main`, then `master`). If the branch already exists, locally or on the remote, it is checked out instead of recreated.

## Cleanup

When the session ends, the wrapper asks:

```text
› Clean up worktree ~/repos/app-fix-broken-login-redirect? [y/N]
```

Answering `y` removes the worktree with `git worktree remove` and deletes the branch when everything on it is already on the base branch.

Saying yes cannot lose work:

- Git refuses to remove a worktree with uncommitted or untracked files.
- A branch with its own commits is kept, and the exact `git branch -D` command to delete it deliberately is printed.

The default is no. Saying no keeps the worktree and prints the removal command for later. The prompt never appears in non-interactive shells, and `SIDEGROVE_CLEANUP_PROMPT=0` disables it entirely.

There is no state file and no tracking: cleanup is a thin prompt over native `git worktree` commands.

## Configuration

Everything is an environment variable, so one-off overrides are just a prefix on the command.

| Variable | Default | Effect |
| --- | --- | --- |
| `SIDEGROVE_BIN` | first `<cli>` on `PATH` | Binary to launch for the wrapped CLI |
| `SIDEGROVE_NAMER` | `local` | `agent` asks the wrapped CLI to name the branch |
| `SIDEGROVE_NAMER_MODEL` | per CLI | Model used for agent naming |
| `SIDEGROVE_NAMER_TIMEOUT` | `8` | Seconds before agent naming falls back to local |
| `SIDEGROVE_SLUG` | derived from the task | Slug used in worktree and branch names |
| `SIDEGROVE_BRANCH_PREFIX` | first word of Git `user.name` | Branch prefix in `<prefix>/<slug>` |
| `SIDEGROVE_BRANCH` | `<prefix>/<slug>` | Full branch name |
| `SIDEGROVE_DIR` | `../<repo>-<slug>` | Worktree path |
| `SIDEGROVE_BASE` | repo default branch | Base branch for new worktrees |
| `SIDEGROVE_FETCH` | `0` | `1` fetches the base branch before creating the worktree |
| `SIDEGROVE_CLEANUP_PROMPT` | `1` | `0` skips the exit-time cleanup prompt |

Examples:

```sh
SIDEGROVE_SLUG=login-redirect claude "Fix login redirect"
SIDEGROVE_BASE=develop codex "Fix login redirect"
SIDEGROVE_BRANCH_PREFIX=alice claude "Fix login redirect"
```

Fetch is off by default so the wrapper stays fast.

## Development

```sh
./scripts/test.sh
```

The tests syntax-check every script, then drive worktree creation, per-CLI argument handling, the interactive prompts, and cleanup end to end in temp repos with temp home directories. The wrapped binary is `/bin/echo` or a small fake, so no real agent session ever starts and your `~/.zshrc` is never touched.

[AGENTS.md](AGENTS.md) covers repo layout and the conventions for changes.

## Design notes

This is intentionally small. It is a launcher, not a session manager.

It cannot change the working directory of a running TUI session. It creates the worktree first, then starts the real CLI inside it.
