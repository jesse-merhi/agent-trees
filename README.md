# Worktree Launcher

Small shell wrapper for starting Codex CLI sessions in task-specific Git worktrees.

The normal flow stays simple:

```sh
codex
```

If you are in the primary checkout of a Git repo, the wrapper asks:

```text
What are we working on? (Enter = use this checkout):
```

Type the task:

```text
Fix login redirect
```

It creates:

```text
../repo-fix-login-redirect
jesse/fix-login-redirect
```

Then it launches:

```sh
/opt/homebrew/bin/codex -C ../repo-fix-login-redirect "Fix login redirect"
```

Press Enter on a blank prompt to run Codex in the current checkout without creating a worktree.

## Install

```sh
git clone git@github.com:jesse-merhi/worktree-launcher.git ~/repos/worktree-launcher
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

The uninstaller removes the installed wrapper and the managed shell block.

If you already had a hand-written alias, the uninstaller leaves it alone and prints a warning.

## Behavior

The wrapper passes these through to the real Codex binary without creating worktrees:

```text
codex -C ...
codex --cd ...
codex --help
codex --version
codex resume
codex fork
codex doctor
codex cloud
codex app
codex update
```

It also passes through when:

```text
you are outside a Git repo
you are already inside a linked worktree
no prompt was provided in a non-interactive shell
the interactive prompt is blank
```

## Settings

Use a custom Codex binary:

```sh
CODEX_BIN=/path/to/codex codex
```

Override the generated slug:

```sh
CODEX_WORKTREE_SLUG=login-redirect codex "Fix login redirect"
```

Override the base branch:

```sh
CODEX_WORKTREE_BASE=develop codex "Fix login redirect"
```

Override the worktree directory or branch:

```sh
CODEX_WORKTREE_DIR=../custom-dir CODEX_WORKTREE_BRANCH=jesse/custom codex "Fix login redirect"
```

Fetch before creating the worktree:

```sh
CODEX_WORKTREE_FETCH=1 codex "Fix login redirect"
```

Fetch is off by default so the wrapper stays fast.

## Test

```sh
./scripts/test.sh
```

The tests use `CODEX_BIN=/bin/echo`, temp repos, and temp home directories. They do not launch a real Codex session.

## Notes

This is intentionally small. It is a launcher, not a session manager.

It cannot change the working directory of a running Codex TUI session. It creates the worktree first, then starts the real CLI with `-C`.
