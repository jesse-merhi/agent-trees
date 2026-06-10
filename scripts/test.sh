#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$repo_root/bin/codex-worktree"
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

assert_rejects_namer() {
  local namer="$1"
  local repo="$tmpdir/reject-$namer"
  local output
  local status

  make_repo "$repo"

  set +e
  output="$(
    cd "$repo"
    CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER="$namer" "$repo_root/bin/codex-worktree" 'Fix Login Redirect' 2>&1
  )"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    printf 'Expected CODEX_WORKTREE_NAMER=%s to fail.\n' "$namer" >&2
    printf 'Actual output:\n%s\n' "$output" >&2
    exit 1
  fi

  assert_contains "$output" "unknown CODEX_WORKTREE_NAMER=$namer"

  if find "$tmpdir" -maxdepth 1 -type d -name "reject-$namer-*" | grep -q .; then
    printf 'Rejected namer %s created a worktree unexpectedly.\n' "$namer" >&2
    exit 1
  fi
}

repo="$tmpdir/demo"
make_repo "$repo"

output="$(
  cd "$repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local HOME="$tmpdir" "$repo_root/bin/codex-worktree" 'Fix Login Redirect' 2>&1
)"

assert_contains "$output" "codex-worktree: ~/demo-fix-login-redirect on test/fix-login-redirect"
assert_contains "$output" "-C "
test -e "$tmpdir/demo-fix-login-redirect/.git"

interactive_repo="$tmpdir/interactive"
make_repo "$interactive_repo"

interactive_output="$(
  cd "$interactive_repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 "$repo_root/bin/codex-worktree"
expect "Describe the task"
expect "› "
send "Fix Login Redirect\r"
expect "Clean up worktree"
send "n\r"
expect eof
EOF
)"

interactive_plain="$(printf '%s' "$interactive_output" | strip_ansi)"

assert_not_contains "$interactive_plain" "Worktree task"
assert_not_contains "$interactive_plain" "------------------------------------------------------------------------"
assert_contains "$interactive_plain" "Describe the task"
assert_contains "$interactive_plain" "› Fix Login Redirect"
assert_contains "$interactive_plain" "› Clean up worktree"
assert_not_contains "$interactive_plain" "Enter = stay here"
assert_contains "$interactive_plain" "interactive-fix-login-redirect"
assert_contains "$interactive_plain" "test/fix-login-redirect"
assert_contains "$interactive_plain" "clean up later with"
assert_contains "$interactive_plain" "worktree remove"
test -e "$tmpdir/interactive-fix-login-redirect/.git"

cleanup_yes_repo="$tmpdir/cleanyes"
make_repo "$cleanup_yes_repo"

cleanup_yes_output="$(
  cd "$cleanup_yes_repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 "$repo_root/bin/codex-worktree" "Fix Login Redirect"
expect "Clean up worktree"
send "y\r"
expect eof
EOF
)"

cleanup_yes_plain="$(printf '%s' "$cleanup_yes_output" | strip_ansi)"

assert_contains "$cleanup_yes_plain" "removed $tmpdir/cleanyes-fix-login-redirect"
assert_contains "$cleanup_yes_plain" "deleted branch test/fix-login-redirect"
test ! -e "$tmpdir/cleanyes-fix-login-redirect"

keep_branch_repo="$tmpdir/keepbranch"
make_repo "$keep_branch_repo"
commit_codex="$tmpdir/commit-codex"
cat > "$commit_codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

dir=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -C)
      dir="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

printf 'work\n' > "$dir/work.txt"
git -C "$dir" add work.txt
git -C "$dir" commit -q -m work
EOF
chmod +x "$commit_codex"

keep_branch_output="$(
  cd "$keep_branch_repo"
  CODEX_BIN="$commit_codex" CODEX_WORKTREE_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 "$repo_root/bin/codex-worktree" "Fix Login Redirect"
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
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local expect <<EOF
log_user 1
spawn env TERM=xterm-256color COLUMNS=72 CODEX_WORKTREE_CLEANUP_PROMPT=0 "$repo_root/bin/codex-worktree" "Fix Login Redirect"
expect eof
EOF
)"

assert_not_contains "$cleanup_off_output" "Clean up worktree"
test -e "$tmpdir/cleanoff-fix-login-redirect/.git"

assert_rejects_namer ollama
assert_rejects_namer llama

codex_repo="$tmpdir/codex"
make_repo "$codex_repo"
fake_codex="$tmpdir/fake-codex"
cat > "$fake_codex" <<'EOF'
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
chmod +x "$fake_codex"

codex_output="$(
  cd "$codex_repo"
  CODEX_BIN="$fake_codex" CODEX_WORKTREE_NAMER=codex "$repo_root/bin/codex-worktree" 'Can you please fix the broken login redirect when users sign in from Google?' 2>&1
)"

assert_contains "$codex_output" "codex-repair-google-signin-redirect"
assert_contains "$codex_output" "test/repair-google-signin-redirect"
test -e "$tmpdir/codex-repair-google-signin-redirect/.git"

override_repo="$tmpdir/override"
make_repo "$override_repo"

override_output="$(
  cd "$override_repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local CODEX_WORKTREE_SLUG='Raw Custom Name' "$repo_root/bin/codex-worktree" 'please use an override' 2>&1
)"

assert_contains "$override_output" "override-raw-custom-name"
assert_contains "$override_output" "test/raw-custom-name"

prefix_repo="$tmpdir/prefix"
make_repo "$prefix_repo"

prefix_output="$(
  cd "$prefix_repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local CODEX_WORKTREE_BRANCH_PREFIX=alice "$repo_root/bin/codex-worktree" 'Fix Login Redirect' 2>&1
)"

assert_contains "$prefix_output" "prefix-fix-login-redirect"
assert_contains "$prefix_output" "alice/fix-login-redirect"

if find "$tmpdir" -type f -name worktrees.tsv | grep -q .; then
  printf 'Wrapper should not create a worktree state file.\n' >&2
  exit 1
fi

blank_repo="$tmpdir/blank"
make_repo "$blank_repo"

blank_output="$(
  cd "$blank_repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local "$repo_root/bin/codex-worktree" 2>&1
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

option_repo="$tmpdir/options"
make_repo "$option_repo"

option_output="$(
  cd "$option_repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local "$repo_root/bin/codex-worktree" review --base origin/main --title 'PR 123' 'Find regressions only' 2>&1
)"

assert_contains "$option_output" "options-find-regressions"
assert_contains "$option_output" "test/find-regressions"

cleanup_passthrough="$(
  cd "$repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local "$repo_root/bin/codex-worktree" cleanup --yes 2>&1
)"

if [[ "$cleanup_passthrough" != "cleanup --yes" ]]; then
  printf 'Expected cleanup to pass through to Codex.\n' >&2
  printf 'Actual output:\n%s\n' "$cleanup_passthrough" >&2
  exit 1
fi

if find "$tmpdir" -maxdepth 1 -type d -name 'demo-cleanup*' | grep -q .; then
  printf 'Cleanup command created a worktree unexpectedly.\n' >&2
  exit 1
fi

install_home="$tmpdir/home"
mkdir -p "$install_home"
mkdir -p "$install_home/.local/state/worktree-launcher"
printf 'old-cache\n' > "$install_home/.local/state/worktree-launcher/worktrees.tsv"
HOME="$install_home" "$repo_root/scripts/install.sh" >/dev/null
test -x "$install_home/.local/bin/codex-worktree"
test ! -e "$install_home/.local/bin/codex-worktree-cleanup"
test ! -e "$install_home/.local/state/worktree-launcher/worktrees.tsv"
grep -Fq "# >>> worktree-launcher >>>" "$install_home/.zshrc"
HOME="$install_home" "$repo_root/scripts/uninstall.sh" >/dev/null
test ! -e "$install_home/.local/bin/codex-worktree"
! grep -Fq "# >>> worktree-launcher >>>" "$install_home/.zshrc"

printf 'All tests passed.\n'
