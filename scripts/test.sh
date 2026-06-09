#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$repo_root/bin/codex-worktree"
python3 -m py_compile "$repo_root/bin/codex-worktree-cleanup"
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

repo="$tmpdir/demo"
make_repo "$repo"

output="$(
  cd "$repo"
  CODEX_BIN=/bin/echo "$repo_root/bin/codex-worktree" 'Fix Login Redirect' 2>&1
)"

assert_contains "$output" "demo-fix-login-redirect"
assert_contains "$output" "jesse/fix-login-redirect"
assert_contains "$output" "-C "
test -e "$tmpdir/demo-fix-login-redirect/.git"

scan_output="$("$repo_root/bin/codex-worktree" cleanup --scan "$tmpdir" 2>&1)"
assert_contains "$scan_output" "demo (1)"
assert_contains "$scan_output" "demo-fix-login-redirect"

if find "$tmpdir" -type f -name worktrees.tsv | grep -q .; then
  printf 'Cleanup should not create a worktree registry file.\n' >&2
  exit 1
fi

blank_repo="$tmpdir/blank"
make_repo "$blank_repo"

blank_output="$(
  cd "$blank_repo"
  CODEX_BIN=/bin/echo "$repo_root/bin/codex-worktree" 2>&1
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
  CODEX_BIN=/bin/echo "$repo_root/bin/codex-worktree" review --base origin/main --title 'PR 123' 'Find regressions only' 2>&1
)"

assert_contains "$option_output" "options-find-regressions-only"
assert_contains "$option_output" "jesse/find-regressions-only"

cleanup_repo="$tmpdir/cleanup"
make_repo "$cleanup_repo"
git -C "$cleanup_repo" worktree add -q -b jesse/remove-me "$tmpdir/cleanup-remove-me"

cleanup_output="$(
  cd "$cleanup_repo"
  "$repo_root/bin/codex-worktree" cleanup --yes 2>&1
)"

assert_contains "$cleanup_output" "removed"
assert_contains "$cleanup_output" "cleanup-remove-me"
test ! -e "$tmpdir/cleanup-remove-me"
test -e "$cleanup_repo/.git"

dirty_repo="$tmpdir/dirty"
make_repo "$dirty_repo"
git -C "$dirty_repo" worktree add -q -b jesse/keep-me "$tmpdir/dirty-keep-me"
printf 'dirty\n' > "$tmpdir/dirty-keep-me/notes.txt"

dirty_output="$(
  cd "$dirty_repo"
  "$repo_root/bin/codex-worktree" cleanup --yes 2>&1
)"

assert_contains "$dirty_output" "skipped dirty"
assert_contains "$dirty_output" "dirty-keep-me"
test -e "$tmpdir/dirty-keep-me/.git"

cleanup_help_output="$("$repo_root/bin/codex-worktree" cleanup --help 2>&1)"
assert_contains "$cleanup_help_output" "usage: codex cleanup"

scan_root="$tmpdir/scan-root"
mkdir -p "$scan_root/group-a" "$scan_root/group-b"
scan_repo_a="$scan_root/group-a/alpha"
scan_repo_b="$scan_root/group-b/beta"
make_repo "$scan_repo_a"
make_repo "$scan_repo_b"
git -C "$scan_repo_a" worktree add -q -b jesse/remove-alpha "$scan_root/group-a/alpha-remove-alpha"
git -C "$scan_repo_b" worktree add -q -b jesse/remove-beta "$scan_root/group-b/beta-remove-beta"

scan_output="$("$repo_root/bin/codex-worktree" cleanup --scan "$scan_root" --yes 2>&1)"

assert_contains "$scan_output" "Scanning $scan_root"
assert_contains "$scan_output" "max depth 4"
assert_contains "$scan_output" "removed"
assert_contains "$scan_output" "group-a/alpha-remove-alpha"
assert_contains "$scan_output" "group-b/beta-remove-beta"
test ! -e "$scan_root/group-a/alpha-remove-alpha"
test ! -e "$scan_root/group-b/beta-remove-beta"

depth_root="$tmpdir/depth-root"
mkdir -p "$depth_root/a/b/c/d"
depth_repo="$depth_root/a/b/c/d/deep"
make_repo "$depth_repo"

depth_output="$("$repo_root/bin/codex-worktree" cleanup --scan "$depth_root" --max-depth 3 2>&1)"

assert_contains "$depth_output" "Scanning $depth_root (max depth 3)"
assert_contains "$depth_output" "No launcher-style sibling worktrees found."

marker_root="$tmpdir/marker-root"
mkdir -p "$marker_root/projects"
marker_repo="$marker_root/projects/gamma"
make_repo "$marker_repo"
git -C "$marker_repo" worktree add -q -b jesse/marker "$marker_root/projects/gamma-marker"

marker_output="$("$repo_root/bin/codex-worktree" cleanup --scan "$marker_root" 2>&1)"

assert_contains "$marker_output" "gamma (1)"
assert_contains "$marker_output" "projects/gamma-marker"

linked_scan_output="$("$repo_root/bin/codex-worktree" cleanup --scan "$marker_root/projects/gamma-marker" 2>&1)"
assert_contains "$linked_scan_output" "gamma (1)"
assert_contains "$linked_scan_output" "[jesse/marker]"

install_home="$tmpdir/home"
mkdir -p "$install_home"
mkdir -p "$install_home/.local/state/worktree-launcher"
printf 'old-cache\n' > "$install_home/.local/state/worktree-launcher/worktrees.tsv"
HOME="$install_home" "$repo_root/scripts/install.sh" >/dev/null
test -x "$install_home/.local/bin/codex-worktree"
test -x "$install_home/.local/bin/codex-worktree-cleanup"
test ! -e "$install_home/.local/state/worktree-launcher/worktrees.tsv"
grep -Fq "# >>> worktree-launcher >>>" "$install_home/.zshrc"
HOME="$install_home" "$repo_root/scripts/uninstall.sh" >/dev/null
test ! -e "$install_home/.local/bin/codex-worktree"
test ! -e "$install_home/.local/bin/codex-worktree-cleanup"
! grep -Fq "# >>> worktree-launcher >>>" "$install_home/.zshrc"

printf 'All tests passed.\n'
