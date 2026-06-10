# Worktree Launcher

Small shell wrapper for starting Codex CLI sessions in task-specific Git worktrees.

The normal flow stays simple:

```sh
codex
```

If you are in the primary checkout of a Git repo, the wrapper asks:

```text
  >  Describe the task
```

Type the task:

```text
Can you please fix the broken login redirect when users sign in from Google?
```

It creates a worktree and branch:

```text
../repo-fix-broken-login-redirect
jesse/fix-broken-login-redirect
```

The branch prefix (`jesse` here) is the first word of your Git `user.name`, lowercased. Override it with `CODEX_WORKTREE_BRANCH_PREFIX`.

Then it launches the real Codex binary in the new worktree:

```sh
codex -C ../repo-fix-broken-login-redirect "Can you please fix the broken login redirect when users sign in from Google?"
```

Press Enter on a blank prompt to run Codex in the current checkout without creating a worktree.

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
codex cleanup
codex worktrees
```

It also passes through when:

```text
you are outside a Git repo
you are already inside a linked worktree
no prompt was provided in a non-interactive shell
the interactive prompt is blank
```

## Cleanup

When the Codex session ends, the wrapper asks:

```text
  >  Clean up worktree ../repo-fix-broken-login-redirect? [y/N]
```

Answering `y` removes the worktree with `git worktree remove` and deletes the branch if it is fully merged. Git refuses to remove a worktree with uncommitted or untracked files, so saying yes cannot lose work.

The default is no. Saying no keeps the worktree and prints the command for later:

```sh
git -C /path/to/repo worktree remove /path/to/repo-fix-broken-login-redirect
```

Skip the prompt entirely:

```sh
CODEX_WORKTREE_CLEANUP_PROMPT=0 codex "Fix login redirect"
```

The prompt also never appears in non-interactive shells.

## Naming

By default, the wrapper uses fast local deterministic naming.

The local fallback lowercases text, removes filler words like `please`, `you`, `the`, and `when`, keeps the first few meaningful words, and caps the result:

```text
Can you please fix the broken login redirect when users sign in from Google?
-> fix-broken-login-redirect
```

Use local fallback naming only:

```sh
CODEX_WORKTREE_NAMER=local codex "Fix login redirect"
```

Use Codex naming:

```sh
CODEX_WORKTREE_NAMER=codex codex "Fix login redirect"
```

Codex naming is opt-in because starting a second Codex agent just to name a worktree is noticeably slower.

## Settings

Use a custom Codex binary (the default is the first `codex` found on `PATH`):

```sh
CODEX_BIN=/path/to/codex codex
```

Override the branch prefix (the default is the first word of your Git `user.name`, falling back to `$USER`, then `codex`):

```sh
CODEX_WORKTREE_BRANCH_PREFIX=alice codex "Fix login redirect"
```

Override the generated slug:

```sh
CODEX_WORKTREE_SLUG=login-redirect codex "Fix login redirect"
```

Override the Codex naming model or timeout:

```sh
CODEX_WORKTREE_NAMER_MODEL=gpt-5.1-codex CODEX_WORKTREE_NAMER_TIMEOUT=4 codex "Fix login redirect"
```

Override the base branch:

```sh
CODEX_WORKTREE_BASE=develop codex "Fix login redirect"
```

Override the worktree directory or the full branch name:

```sh
CODEX_WORKTREE_DIR=../custom-dir CODEX_WORKTREE_BRANCH=alice/custom codex "Fix login redirect"
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

`AGENTS.md` covers repo layout and conventions. `docs/prior-art.md` covers why this exists.
