#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bin_dir="${WORKTREE_LAUNCHER_BIN_DIR:-$HOME/.local/bin}"
shell_rc="${WORKTREE_LAUNCHER_SHELL_RC:-$HOME/.zshrc}"
target="$bin_dir/codex-worktree"
cleanup_target="$bin_dir/codex-worktree-cleanup"
obsolete_state_file="$HOME/.local/state/worktree-launcher/worktrees.tsv"

mkdir -p "$bin_dir"
install -m 0755 "$repo_root/bin/codex-worktree" "$target"
install -m 0755 "$repo_root/bin/codex-worktree-cleanup" "$cleanup_target"

if [[ -f "$obsolete_state_file" ]]; then
  rm -f "$obsolete_state_file"
  printf 'Removed obsolete %s\n' "$obsolete_state_file"
fi

if [[ ! -e "$shell_rc" ]]; then
  touch "$shell_rc"
fi

if grep -Fq "# >>> worktree-launcher >>>" "$shell_rc"; then
  tmp_file="$(mktemp)"
  awk '
    $0 == "# >>> worktree-launcher >>>" { in_block = 1; next }
    $0 == "# <<< worktree-launcher <<<" { in_block = 0; next }
    !in_block { print }
  ' "$shell_rc" > "$tmp_file"
  mv "$tmp_file" "$shell_rc"
fi

if grep -Eq "^[[:space:]]*alias[[:space:]]+codex=['\"]codex-worktree['\"]" "$shell_rc"; then
  printf 'Installed %s\n' "$target"
  printf 'Installed %s\n' "$cleanup_target"
  printf 'Existing codex alias found in %s; leaving it in place.\n' "$shell_rc"
  exit 0
fi

cat >> "$shell_rc" <<'EOF'

# >>> worktree-launcher >>>
if command -v codex-worktree >/dev/null 2>&1; then
  alias codex='codex-worktree'
fi
# <<< worktree-launcher <<<
EOF

printf 'Installed %s\n' "$target"
printf 'Installed %s\n' "$cleanup_target"
printf 'Added shell alias block to %s\n' "$shell_rc"
printf 'Restart your shell or run: source %s\n' "$shell_rc"
