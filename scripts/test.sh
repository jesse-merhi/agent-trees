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

repo="$tmpdir/demo"
make_repo "$repo"

output="$(
  cd "$repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local "$repo_root/bin/codex-worktree" 'Fix Login Redirect' 2>&1
)"

assert_contains "$output" "demo-fix-login-redirect"
assert_contains "$output" "jesse/fix-login-redirect"
assert_contains "$output" "-C "
test -e "$tmpdir/demo-fix-login-redirect/.git"

noisy_repo="$tmpdir/noisy"
make_repo "$noisy_repo"
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

noisy_output="$(
  cd "$noisy_repo"
  CODEX_BIN="$fake_codex" "$repo_root/bin/codex-worktree" 'Can you please fix the broken login redirect when users sign in from Google?' 2>&1
)"

assert_contains "$noisy_output" "noisy-repair-google-signin-redirect"
assert_contains "$noisy_output" "jesse/repair-google-signin-redirect"
test -e "$tmpdir/noisy-repair-google-signin-redirect/.git"

override_repo="$tmpdir/override"
make_repo "$override_repo"

override_output="$(
  cd "$override_repo"
  CODEX_BIN=/bin/echo CODEX_WORKTREE_NAMER=local CODEX_WORKTREE_SLUG='Raw Custom Name' "$repo_root/bin/codex-worktree" 'please use an override' 2>&1
)"

assert_contains "$override_output" "override-raw-custom-name"
assert_contains "$override_output" "jesse/raw-custom-name"

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
assert_contains "$option_output" "jesse/find-regressions"

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
