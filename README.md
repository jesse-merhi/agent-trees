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
Can you please fix the broken login redirect when users sign in from Google?
```

It creates:

```text
../repo-fix-broken-login-redirect
jesse/fix-broken-login-redirect
```

Then it launches:

```sh
/opt/homebrew/bin/codex -C ../repo-fix-broken-login-redirect "Can you please fix the broken login redirect when users sign in from Google?"
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

## Naming

By default, the wrapper uses fast local deterministic naming.

For smarter names, the wrapper can ask local Ollama for a short slug before creating the worktree:

```sh
CODEX_WORKTREE_NAMER=ollama codex "Fix login redirect"
```

The wrapper calls Ollama's local HTTP API with `smollm2:360m`, validates the returned slug, and falls back to local deterministic naming if Ollama is unavailable, slow, or returns invalid output.

Ollama naming is opt-in because warm calls are fast, but cold model starts can add several seconds.

The local fallback lowercases text, removes filler words like `please`, `you`, `the`, and `when`, keeps the first few meaningful words, and caps the result:

```text
Can you please fix the broken login redirect when users sign in from Google?
-> fix-broken-login-redirect
```

Use local fallback naming only:

```sh
CODEX_WORKTREE_NAMER=local codex "Fix login redirect"
```

Use Ollama naming:

```sh
CODEX_WORKTREE_NAMER=ollama codex "Fix login redirect"
```

Use Codex naming:

```sh
CODEX_WORKTREE_NAMER=codex codex "Fix login redirect"
```

Codex naming is opt-in because starting a second Codex agent just to name a worktree is noticeably slower.

The benchmark from this machine is in:

```text
docs/slug-namer-benchmark.md
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

Override the Ollama model or timeout:

```sh
CODEX_WORKTREE_OLLAMA_MODEL=smollm2:360m CODEX_WORKTREE_OLLAMA_TIMEOUT=4 codex "Fix login redirect"
```

Override the Codex naming model or timeout:

```sh
CODEX_WORKTREE_NAMER_MODEL=gpt-5.1-codex CODEX_WORKTREE_NAMER_TIMEOUT=4 codex "Fix login redirect"
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
