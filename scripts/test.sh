#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$repo_root/bin/agent-trees"
bash -n "$repo_root/scripts/install.sh"
bash -n "$repo_root/scripts/uninstall.sh"

tmpdir="$(mktemp -d)"
tmpdir="$(cd "$tmpdir" && pwd -P)"
trap 'rm -rf "$tmpdir"' EXIT

make_repo() {
  local repo="$1"

  git init -q -b main "$repo"
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name Test
  printf 'hello\n' > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -q -m initial
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

strip_ansi() {
  sed -E $'s/\x1b\\[[0-9;]*[A-Za-z]//g'
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'Expected output not to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s\n' "$haystack" >&2
    exit 1
  fi
}

fake_cli="$tmpdir/fake-cli"
cat > "$fake_cli" <<'EOF'
#!/bin/sh
printf 'PWD:%s ARGS:%s\n' "$PWD" "$*"
EOF
chmod +x "$fake_cli"

# --- usage ---

set +e
usage_output="$("$repo_root/bin/agent-trees" 2>&1)"
usage_status=$?
set -e

if [[ "$usage_status" -ne 2 ]]; then
  printf 'Expected exit 2 for missing CLI argument, got %s.\n' "$usage_status" >&2
  exit 1
fi
assert_contains "$usage_output" "Usage: agent-trees <cli>"

help_output="$("$repo_root/bin/agent-trees" --help 2>&1)"
assert_contains "$help_output" "Usage: agent-trees <cli>"

# --- basic worktree creation, ~ display, and launch directory ---

repo="$tmpdir/demo"
make_repo "$repo"

output="$(
  cd "$repo"
  AGENT_TREES_BIN="$fake_cli" AGENT_TREES_NAMER=local HOME="$tmpdir" \
    "$repo_root/bin/agent-trees" codex 'Fix Login Redirect' 2>&1
)"

assert_contains "$output" "agent-trees: ~/demo-fix-login-redirect on test/fix-login-redirect"
assert_contains "$output" "PWD:$tmpdir/demo-fix-login-redirect"
assert_contains "$output" "ARGS:Fix Login Redirect"
test -e "$tmpdir/demo-fix-login-redirect/.git"

# --- per-CLI option semantics ---

# For codex, -p takes a value (profile); it must not leak into the slug.
codex_profile_repo="$tmpdir/codexprofile"
make_repo "$codex_profile_repo"

codex_profile_output="$(
  cd "$codex_profile_repo"
  AGENT_TREES_BIN="$fake_cli" AGENT_TREES_NAMER=local \
    "$repo_root/bin/agent-trees" codex -p myprofile 'Fix Login Redirect' 2>&1
)"

assert_contains "$codex_profile_output" "test/fix-login-redirect"
test -e "$tmpdir/codexprofile-fix-login-redirect/.git"

# For claude, --model takes a value; it must not leak into the slug.
claude_model_repo="$tmpdir/claudemodel"
make_repo "$claude_model_repo"

claude_model_output="$(
  cd "$claude_model_repo"
  AGENT_TREES_BIN="$fake_cli" AGENT_TREES_NAMER=local \
    "$repo_root/bin/agent-trees" claude --model fable 'Fix Login Redirect' 2>&1
)"

assert_contains "$claude_model_output" "test/fix-login-redirect"
test -e "$tmpdir/claudemodel-fix-login-redirect/.git"

# For claude, -p is print mode: pass through without a worktree.
claude_print_repo="$tmpdir/claudeprint"
make_repo "$claude_print_repo"

claude_print_output="$(
  cd "$claude_print_repo"
  AGENT_TREES_BIN="$fake_cli" AGENT_TREES_NAMER=local \
    "$repo_root/bin/agent-trees" claude -p 'What does this repo do?' 2>&1
)"

assert_contains "$claude_print_output" "ARGS:-p What does this repo do?"
assert_contains "$claude_print_output" "PWD:$tmpdir/claudeprint"
if find "$tmpdir" -maxdepth 1 -type d -name 'claudeprint-*' | grep -q .; then
  printf 'claude -p created a worktree unexpectedly.\n' >&2
  exit 1
fi

# Resume flows and management subcommands pass through.
claude_resume_output="$(
  cd "$claude_print_repo"
  AGENT_TREES_BIN="$fake_cli" "$repo_root/bin/agent-trees" claude -c 2>&1
)"
assert_contains "$claude_resume_output" "ARGS:-c"

claude_mcp_output="$(
  cd "$claude_print_repo"
  AGENT_TREES_BIN="$fake_cli" "$repo_root/bin/agent-trees" claude mcp list 2>&1
)"
assert_contains "$claude_mcp_output" "ARGS:mcp list"

codex_cleanup_passthrough="$(
  cd "$repo"
  AGENT_TREES_BIN=/bin/echo "$repo_root/bin/agent-trees" codex cleanup --yes 2>&1
)"

if [[ "$codex_cleanup_passthrough" != "cleanup --yes" ]]; then
  printf 'Expected codex cleanup to pass through.\n' >&2
  printf 'Actual output:\n%s\n' "$codex_cleanup_passthrough" >&2
  exit 1
fi

# Unknown CLIs still work with generic defaults.
generic_repo="$tmpdir/generic"
make_repo "$generic_repo"

generic_output="$(
  cd "$generic_repo"
  AGENT_TREES_BIN="$fake_cli" AGENT_TREES_NAMER=local \
    "$repo_root/bin/agent-trees" somecli 'Fix Login Redirect' 2>&1
)"

assert_contains "$generic_output" "test/fix-login-redirect"
test -e "$tmpdir/generic-fix-login-redirect/.git"

# --- interactive prompt and cleanup ---

interactive_repo="$tmpdir/interactive"
make_repo "$interactive_repo"

interactive_output="$(
  cd "$interactive_repo"
  AGENT_TREES_BIN=/bin/echo AGENT_TREES_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 "$repo_root/bin/agent-trees" codex
expect "Describe the task"
expect "› "
send "Fix Login Redirect\r"
expect "Clean up worktree"
send "n\r"
expect eof
EOF
)"

interactive_plain="$(printf '%s' "$interactive_output" | strip_ansi)"

assert_contains "$interactive_plain" "Describe the task"
assert_contains "$interactive_plain" "› Fix Login Redirect"
assert_contains "$interactive_plain" "› Clean up worktree"
assert_contains "$interactive_plain" "interactive-fix-login-redirect"
assert_contains "$interactive_plain" "test/fix-login-redirect"
assert_contains "$interactive_plain" "clean up later with"
assert_contains "$interactive_plain" "worktree remove"
test -e "$tmpdir/interactive-fix-login-redirect/.git"

cleanup_yes_repo="$tmpdir/cleanyes"
make_repo "$cleanup_yes_repo"

cleanup_yes_output="$(
  cd "$cleanup_yes_repo"
  AGENT_TREES_BIN=/bin/echo AGENT_TREES_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 "$repo_root/bin/agent-trees" codex "Fix Login Redirect"
expect "Clean up worktree"
send "y\r"
expect eof
EOF
)"

cleanup_yes_plain="$(printf '%s' "$cleanup_yes_output" | strip_ansi)"

assert_contains "$cleanup_yes_plain" "removing $tmpdir/cleanyes-fix-login-redirect ..."
assert_contains "$cleanup_yes_plain" "removed $tmpdir/cleanyes-fix-login-redirect"
assert_contains "$cleanup_yes_plain" "deleted branch test/fix-login-redirect"
test ! -e "$tmpdir/cleanyes-fix-login-redirect"

keep_branch_repo="$tmpdir/keepbranch"
make_repo "$keep_branch_repo"
commit_cli="$tmpdir/commit-cli"
cat > "$commit_cli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'work\n' > work.txt
git add work.txt
git commit -q -m work
EOF
chmod +x "$commit_cli"

keep_branch_output="$(
  cd "$keep_branch_repo"
  AGENT_TREES_BIN="$commit_cli" AGENT_TREES_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 "$repo_root/bin/agent-trees" codex "Fix Login Redirect"
expect "Clean up worktree"
send "y\r"
expect eof
EOF
)"

keep_branch_plain="$(printf '%s' "$keep_branch_output" | strip_ansi)"

assert_contains "$keep_branch_plain" "removed $tmpdir/keepbranch-fix-login-redirect"
assert_contains "$keep_branch_plain" "kept branch test/fix-login-redirect (has commits not on main)"
assert_contains "$keep_branch_plain" "branch -D"
test ! -e "$tmpdir/keepbranch-fix-login-redirect"
git -C "$keep_branch_repo" rev-parse --verify --quiet test/fix-login-redirect >/dev/null

cleanup_off_repo="$tmpdir/cleanoff"
make_repo "$cleanup_off_repo"

cleanup_off_output="$(
  cd "$cleanup_off_repo"
  AGENT_TREES_BIN=/bin/echo AGENT_TREES_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 AGENT_TREES_CLEANUP_PROMPT=0 "$repo_root/bin/agent-trees" codex "Fix Login Redirect"
expect eof
EOF
)"

assert_not_contains "$cleanup_off_output" "Clean up worktree"
test -e "$tmpdir/cleanoff-fix-login-redirect/.git"

# --- naming ---

assert_rejects_namer() {
  local namer="$1"
  local repo="$tmpdir/reject-$namer"
  local output
  local status

  make_repo "$repo"

  set +e
  output="$(
    cd "$repo"
    AGENT_TREES_BIN=/bin/echo AGENT_TREES_NAMER="$namer" \
      "$repo_root/bin/agent-trees" codex 'Fix Login Redirect' 2>&1
  )"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    printf 'Expected AGENT_TREES_NAMER=%s to fail.\n' "$namer" >&2
    printf 'Actual output:\n%s\n' "$output" >&2
    exit 1
  fi

  assert_contains "$output" "unknown AGENT_TREES_NAMER=$namer"

  if find "$tmpdir" -maxdepth 1 -type d -name "reject-$namer-*" | grep -q .; then
    printf 'Rejected namer %s created a worktree unexpectedly.\n' "$namer" >&2
    exit 1
  fi
}

assert_rejects_namer ollama
assert_rejects_namer codex

codex_namer_repo="$tmpdir/codexnamer"
make_repo "$codex_namer_repo"
fake_codex_namer="$tmpdir/fake-codex-namer"
cat > "$fake_codex_namer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output_file=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o|--output-last-message)
      output_file="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n "$output_file" ]]; then
  printf 'repair-google-signin-redirect\n' > "$output_file"
fi
EOF
chmod +x "$fake_codex_namer"

codex_namer_output="$(
  cd "$codex_namer_repo"
  AGENT_TREES_BIN="$fake_codex_namer" AGENT_TREES_NAMER=agent \
    "$repo_root/bin/agent-trees" codex 'Can you please fix the broken login redirect when users sign in from Google?' 2>&1
)"

assert_contains "$codex_namer_output" "codexnamer-repair-google-signin-redirect"
assert_contains "$codex_namer_output" "test/repair-google-signin-redirect"
test -e "$tmpdir/codexnamer-repair-google-signin-redirect/.git"

claude_namer_repo="$tmpdir/claudenamer"
make_repo "$claude_namer_repo"
fake_claude_namer="$tmpdir/fake-claude-namer"
cat > "$fake_claude_namer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

for arg in "$@"; do
  if [[ "$arg" == "-p" ]]; then
    printf 'repair-google-signin-redirect\n'
    exit 0
  fi
done

printf 'PWD:%s ARGS:%s\n' "$PWD" "$*"
EOF
chmod +x "$fake_claude_namer"

claude_namer_output="$(
  cd "$claude_namer_repo"
  AGENT_TREES_BIN="$fake_claude_namer" AGENT_TREES_NAMER=agent \
    "$repo_root/bin/agent-trees" claude 'Can you please fix the broken login redirect when users sign in from Google?' 2>&1
)"

assert_contains "$claude_namer_output" "claudenamer-repair-google-signin-redirect"
assert_contains "$claude_namer_output" "test/repair-google-signin-redirect"
test -e "$tmpdir/claudenamer-repair-google-signin-redirect/.git"

# --- overrides ---

override_repo="$tmpdir/override"
make_repo "$override_repo"

override_output="$(
  cd "$override_repo"
  AGENT_TREES_BIN=/bin/echo AGENT_TREES_NAMER=local AGENT_TREES_SLUG='Raw Custom Name' \
    "$repo_root/bin/agent-trees" codex 'please use an override' 2>&1
)"

assert_contains "$override_output" "override-raw-custom-name"
assert_contains "$override_output" "test/raw-custom-name"

prefix_repo="$tmpdir/prefix"
make_repo "$prefix_repo"

prefix_output="$(
  cd "$prefix_repo"
  AGENT_TREES_BIN=/bin/echo AGENT_TREES_NAMER=local AGENT_TREES_BRANCH_PREFIX=alice \
    "$repo_root/bin/agent-trees" codex 'Fix Login Redirect' 2>&1
)"

assert_contains "$prefix_output" "prefix-fix-login-redirect"
assert_contains "$prefix_output" "alice/fix-login-redirect"

# --- quiet blank pass-through ---

blank_repo="$tmpdir/blank"
make_repo "$blank_repo"

blank_output="$(
  cd "$blank_repo"
  AGENT_TREES_BIN=/bin/echo AGENT_TREES_NAMER=local "$repo_root/bin/agent-trees" codex 2>&1
)"

if find "$tmpdir" -maxdepth 1 -type d -name 'blank-*' | grep -q .; then
  printf 'Blank run created a worktree unexpectedly.\n' >&2
  exit 1
fi

if [[ "$blank_output" != "" ]]; then
  printf 'Blank non-interactive run should pass through quietly.\n' >&2
  printf 'Actual output:\n%s\n' "$blank_output" >&2
  exit 1
fi

# --- install and uninstall, including migration from worktree-launcher ---

install_home="$tmpdir/home"
mkdir -p "$install_home/.local/bin"
printf '#!/bin/sh\n' > "$install_home/.local/bin/codex-worktree"
chmod +x "$install_home/.local/bin/codex-worktree"
printf '#!/bin/sh\n' > "$install_home/.local/bin/sidegrove"
chmod +x "$install_home/.local/bin/sidegrove"
mkdir -p "$install_home/.local/state/worktree-launcher"
printf 'old-cache\n' > "$install_home/.local/state/worktree-launcher/worktrees.tsv"
cat > "$install_home/.zshrc" <<'EOF'
# >>> worktree-launcher >>>
if command -v codex-worktree >/dev/null 2>&1; then
  alias codex='codex-worktree'
fi
# <<< worktree-launcher <<<
# >>> sidegrove >>>
if command -v sidegrove >/dev/null 2>&1; then
  alias codex='sidegrove codex'
fi
# <<< sidegrove <<<
if command -v codex-worktree >/dev/null 2>&1; then
  alias codex='codex-worktree'
fi
alias claude='my-custom-claude'
EOF

install_output="$(HOME="$install_home" "$repo_root/scripts/install.sh")"

test -x "$install_home/.local/bin/agent-trees"
test ! -e "$install_home/.local/bin/codex-worktree"
test ! -e "$install_home/.local/bin/sidegrove"
test ! -e "$install_home/.local/state/worktree-launcher/worktrees.tsv"
assert_contains "$install_output" "Existing claude alias found"
zshrc_content="$(cat "$install_home/.zshrc")"
assert_not_contains "$zshrc_content" "worktree-launcher"
assert_not_contains "$zshrc_content" "sidegrove"
assert_contains "$zshrc_content" "# >>> agent-trees >>>"
assert_contains "$zshrc_content" "alias codex='agent-trees codex'"
assert_not_contains "$zshrc_content" "alias claude='agent-trees claude'"
assert_contains "$zshrc_content" "alias claude='my-custom-claude'"

HOME="$install_home" "$repo_root/scripts/uninstall.sh" >/dev/null
test ! -e "$install_home/.local/bin/agent-trees"
zshrc_content="$(cat "$install_home/.zshrc")"
assert_not_contains "$zshrc_content" "# >>> agent-trees >>>"
assert_contains "$zshrc_content" "alias claude='my-custom-claude'"

fresh_home="$tmpdir/freshhome"
mkdir -p "$fresh_home"
HOME="$fresh_home" "$repo_root/scripts/install.sh" >/dev/null
fresh_zshrc="$(cat "$fresh_home/.zshrc")"
assert_contains "$fresh_zshrc" "alias codex='agent-trees codex'"
assert_contains "$fresh_zshrc" "alias claude='agent-trees claude'"

# Piped install (curl ... | bash): no script file on disk, binary fetched
# from the raw URL. file:// keeps the test offline.
pipe_home="$tmpdir/pipehome"
mkdir -p "$pipe_home"
HOME="$pipe_home" AGENT_TREES_RAW_BASE="file://$repo_root" \
  bash < "$repo_root/scripts/install.sh" >/dev/null
test -x "$pipe_home/.local/bin/agent-trees"
diff -q "$repo_root/bin/agent-trees" "$pipe_home/.local/bin/agent-trees" >/dev/null
grep -Fq "# >>> agent-trees >>>" "$pipe_home/.zshrc"

printf 'All tests passed.\n'
