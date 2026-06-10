# agent-trees

A small Bash wrapper that gives every coding-agent task its own Git worktree and branch, without changing the commands you type. Works with Codex CLI, Claude Code, and any similar CLI.

You still type `claude`. From the primary checkout of a repo, a session looks like this:

```text
  Describe the task
› fix the broken login redirect when users sign in from Google

agent-trees: ~/repos/app-fix-broken-login-redirect on jesse/fix-broken-login-redirect

... your normal claude session, running inside the new worktree ...

› Clean up worktree ~/repos/app-fix-broken-login-redirect? [y/N] y
agent-trees: removed ~/repos/app-fix-broken-login-redirect
agent-trees: deleted branch jesse/fix-broken-login-redirect
```

Each task gets an isolated checkout, so parallel agent sessions never trip over each other and your main checkout stays clean. Press Enter on a blank prompt to stay in the current checkout.

Doing this by hand means naming a branch, creating the worktree, starting the agent there, and remembering to remove it later. agent-trees folds all of that into the command you already type. [docs/prior-art.md](docs/prior-art.md) covers the background.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jesse-merhi/agent-trees/main/scripts/install.sh | bash
source ~/.zshrc
```

From a clone, `./scripts/install.sh` does the same thing. Either way it installs one binary, `~/.local/bin/agent-trees`, and adds a managed alias block to `~/.zshrc`:

```sh
alias codex='agent-trees codex'
alias claude='agent-trees claude'
```

Each alias is guarded by a `command -v` check, aliases you wrote yourself are left alone, and old `worktree-launcher` or `sidegrove` installs migrate automatically. Uninstalling works the same way, piped or from a clone:

```sh
curl -fsSL https://raw.githubusercontent.com/jesse-merhi/agent-trees/main/scripts/uninstall.sh | bash
```

Any other CLI works with safe generic defaults:

```sh
alias mycli='agent-trees mycli'
```

Requirements: macOS or Linux with Bash 3.2+, Git 2.5+, your agent CLIs on `PATH`. `python3` is needed only for `AGENT_TREES_NAMER=agent`, and `expect` only for the test suite.

## When it stays out of the way

`codex` and `claude` get tailored argument handling. The wrapper steps in only for fresh task sessions; all of these go straight to the real binary:

- management subcommands (`mcp`, `doctor`, `update`, `login`, ...)
- resume flows (`codex resume`, `claude -c` / `-r`)
- `claude -p` print mode and `claude -w` native worktrees
- explicit directory flags (`codex -C ...`), `--help`, `--version`
- outside a Git repo, or already inside a linked worktree
- no task given: a blank prompt, or a non-interactive shell with no arguments

## Branches and naming

```text
~/repos/app                              your checkout
~/repos/app-fix-broken-login-redirect    the task worktree
jesse/fix-broken-login-redirect          its branch
```

The branch is `<prefix>/<slug>`. The prefix is the first word of your Git `user.name`, falling back to `$USER`, then `agent`. The slug comes from the task text: lowercase, filler words dropped, first few meaningful words kept.

```text
Can you please fix the broken login redirect when users sign in from Google?
-> fix-broken-login-redirect
```

New worktrees branch from the repo's default branch. A branch that already exists, locally or on the remote, is checked out and reused.

You can ask the agent itself to name the branch (a tiny `codex exec` or fast-model `claude -p` call). It adds a few seconds and falls back to local naming on failure:

```sh
AGENT_TREES_NAMER=agent claude "Fix login redirect"
```

## Cleanup

Answering `y` to the exit prompt removes the worktree with `git worktree remove` and deletes the branch when everything on it is already on the base branch. Saying yes cannot lose work:

- Git refuses to remove a worktree with uncommitted or untracked files.
- A branch with its own commits is kept, and the exact `git branch -D` command to delete it deliberately is printed.

The default is no, which keeps the worktree and prints the removal command for later. The prompt only appears in interactive shells. Cleanup runs plain `git worktree` commands and keeps zero state.

## Configuration

Everything is an environment variable, so one-off overrides are just a prefix on the command:

```sh
AGENT_TREES_BASE=develop codex "Fix login redirect"
```

| Variable | Default | Effect |
| --- | --- | --- |
| `AGENT_TREES_BIN` | first `<cli>` on `PATH` | Binary to launch for the wrapped CLI |
| `AGENT_TREES_NAMER` | `local` | `agent` asks the wrapped CLI to name the branch |
| `AGENT_TREES_NAMER_MODEL` | per CLI | Model used for agent naming |
| `AGENT_TREES_NAMER_TIMEOUT` | `8` | Seconds before agent naming falls back to local |
| `AGENT_TREES_SLUG` | derived from the task | Slug used in worktree and branch names |
| `AGENT_TREES_BRANCH_PREFIX` | first word of Git `user.name` | Branch prefix in `<prefix>/<slug>` |
| `AGENT_TREES_BRANCH` | `<prefix>/<slug>` | Full branch name |
| `AGENT_TREES_DIR` | `../<repo>-<slug>` | Worktree path |
| `AGENT_TREES_BASE` | repo default branch | Base branch for new worktrees |
| `AGENT_TREES_FETCH` | `0` | `1` fetches the base branch before creating the worktree |
| `AGENT_TREES_CLEANUP_PROMPT` | `1` | `0` skips the exit-time cleanup prompt |

## Development

`./scripts/test.sh` syntax-checks every script, then drives worktree creation, per-CLI argument handling, the interactive prompts, and cleanup end to end in temp repos with temp home directories. No real agent session starts and your `~/.zshrc` is never touched. [AGENTS.md](AGENTS.md) covers repo layout and conventions.

The whole tool is one Bash script: it creates a worktree, starts the real CLI inside it, and asks one cleanup question on exit. It cannot change the directory of a running TUI session, which is why the worktree is created first.
