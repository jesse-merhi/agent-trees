# Prior Art

This wrapper exists because local CLI worktree flow is still mostly a userland problem.

Git itself already ships the core cleanup commands:

```sh
git worktree list
git worktree remove <path>
git worktree prune
```

`git worktree prune` cleans stale Git metadata for worktrees whose directories are already gone. This wrapper does not add a cleanup layer; cleanup stays with native Git commands.

## What others are doing

Several guides describe the same basic pattern:

```text
create a Git worktree
start the agent with that directory as its working root
keep parallel tasks isolated by branch and checkout
```

Examples found during search:

- frr.dev says the Codex CLI does not have a native `--worktree` flow and shows manual Git worktree setup:
  `https://www.frr.dev/posts/codex-cli-worktrees-manual-parallelism/`
- GitWorktree.org documents a Codex + Docker + Git worktree workflow:
  `https://www.gitworktree.org/ai-tools/codex-docker`
- Inventive HQ has a guide for using Git worktrees with Codex CLI:
  `https://inventivehq.com/knowledge-base/openai/how-to-use-git-worktrees`
- BSWEN shows running multiple Codex tasks in parallel with Git worktrees:
  `https://docs.bswen.com/blog/2026-02-23-codex-parallel-git-worktrees/`
- Reddit discussions include people wrapping small CLI harnesses around Codex for worktree management:
  `https://www.reddit.com/r/codex/comments/1sc7g2x/how_are_you_actually_running_codex_at_scale/`

The Codex app also has built-in worktree support. The local CLI path is the gap this wrapper targets.

## Difference here

This wrapper keeps the command you already type:

```sh
codex
```

It asks for a first task prompt, turns that into a branch and worktree name, then launches the real CLI with:

```sh
codex -C <worktree>
```

It avoids automatic anonymous `scratch-*` directories. Blank input means:

```text
use this checkout
```

It also avoids fetching by default. Fetching can be slow, and most local sessions do not need it before creating a task worktree.
