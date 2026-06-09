#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n "$repo_root/bin/codex-worktree"
bash -n "$repo_root/scripts/install.sh"
bash -n "$repo_root/scripts/uninstall.sh"

tmpdir="$(mktemp -d)"
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

install_home="$tmpdir/home"
mkdir -p "$install_home"
HOME="$install_home" "$repo_root/scripts/install.sh" >/dev/null
test -x "$install_home/.local/bin/codex-worktree"
grep -Fq "# >>> worktree-launcher >>>" "$install_home/.zshrc"
HOME="$install_home" "$repo_root/scripts/uninstall.sh" >/dev/null
test ! -e "$install_home/.local/bin/codex-worktree"
! grep -Fq "# >>> worktree-launcher >>>" "$install_home/.zshrc"

printf 'All tests passed.\n'
