# Slug Namer Benchmark

Machine:

```text
Apple M4 Pro
48 GB RAM
Ollama 0.23.2
```

Prompt shape:

```text
Create a git branch/worktree slug for this task.
Return only the slug.
Use lowercase kebab-case.
Use 2 to 5 meaningful words.
Max 48 characters.
```

Six task prompts were used. A result counted as valid when the sanitized slug matched:

```text
^[a-z0-9][a-z0-9-]{1,47}$
```

`keyword` means the slug kept at least one expected task keyword.

| Model | Size | Cold | Warm p50 | Valid | Keyword | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `gemma3:270m` | 292 MB | 12.6s | 227ms | 0/6 | 0/6 | Smallest, but unusable for strict slug output |
| `qwen2.5:0.5b-instruct` | 398 MB | 27.9s | 142ms | 6/6 | 6/6 | Good output, bad cold start |
| `qwen3:0.6b` | 523 MB | 2.1s | 219ms | 0/6 | 0/6 | Returned empty output with this prompt |
| `smollm2:360m` | 726 MB | 3.1s | 102ms | 6/6 | 6/6 | Best default |
| `llama3.2:1b` | 1.3 GB | 12.5s | 226ms | 6/6 | 5/6 | Larger and slower |
| `qwen2.5:1.5b` | 986 MB | 10.1s | 215ms | 6/6 | 6/6 | Good, but slower than `smollm2:360m` |
| `qwen3:1.7b` | 1.4 GB | 34.5s | 423ms | 0/6 | 0/6 | Returned empty output with this prompt |

Sample `smollm2:360m` outputs:

```text
fix_broken_login_redirect -> fix-broken-login-redirect
`cleanup_worktree_wrapper` -> cleanup-worktree-wrapper
`official_badges` -> official-badges
`playwright-auth-spam` -> playwright-auth-spam
`publish_form_reject_malicious_package_manifest` -> publish-form-reject-malicious-package-manifest
`mega-management-route-components` -> mega-management-route-components
```

Follow-up smoke tests:

```text
installed wrapper + real Ollama cold path: 5.9s, fell back locally
same with 8s timeout: 9.5s, fell back locally
direct smollm2 cold prompt after Ollama restart: timed out at 30s once
ollama run smollm2:360m simple prompt: 17.4s
```

Direct `llama-cli` tests:

```text
llama.cpp 9570
qwen2.5:0.5b-instruct GGUF from Ollama
no Ollama generation API
no llama.cpp warmup run
```

| Path | Model | Extra setup | Timings | Quality | Result |
| --- | --- | --- | ---: | ---: | --- |
| `CODEX_WORKTREE_NAMER=llama` | `qwen2.5:0.5b-instruct` | `ollama show --modelfile` path lookup, then direct `llama-cli` | 1.1-1.8s model call | 5/6 good raw outputs | Best no-warm smart option |

The weak direct-llama case was:

```text
Task: ok remove all the worktree cleanup shit and make current worktree names less scuffed
Raw Qwen slug: git-keep
Fallback slug: remove-all-worktree-cleanup
```

The wrapper rejects direct-llama slugs that do not share any meaningful word with the task, then falls back to deterministic local naming.

Real wrapper smoke tests:

```text
CODEX_WORKTREE_NAMER=llama CODEX_BIN=/bin/echo "Can you please fix the broken login redirect when users sign in from Google?"
-> demo-google-login-fix
real 2.18s including git worktree add

CODEX_WORKTREE_NAMER=llama CODEX_BIN=/bin/echo "ok remove all the worktree cleanup shit and make current worktree names less scuffed"
-> demo-remove-all-worktree-cleanup
real 2.26s including git worktree add
```

Decision:

```text
Keep local deterministic naming as the default.
Use Ollama with smollm2:360m as an opt-in smarter namer.
Use direct llama.cpp with qwen2.5:0.5b-instruct as the opt-in no-warm smarter namer.
Keep Codex naming opt-in only.
```
