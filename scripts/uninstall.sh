#!/usr/bin/env bash
set -euo pipefail

bin_dir="${WORKTREE_LAUNCHER_BIN_DIR:-$HOME/.local/bin}"
shell_rc="${WORKTREE_LAUNCHER_SHELL_RC:-$HOME/.zshrc}"
target="$bin_dir/codex-worktree"

if [[ -e "$target" ]]; then
  rm -f "$target"
  printf 'Removed %s\n' "$target"
fi

if [[ -e "$shell_rc" ]] && grep -Fq "# >>> worktree-launcher >>>" "$shell_rc"; then
  tmp_file="$(mktemp)"
  awk '
    $0 == "# >>> worktree-launcher >>>" { in_block = 1; next }
    $0 == "# <<< worktree-launcher <<<" { in_block = 0; next }
    !in_block { print }
  ' "$shell_rc" > "$tmp_file"
  mv "$tmp_file" "$shell_rc"
  printf 'Removed shell alias block from %s\n' "$shell_rc"
fi

if [[ -e "$shell_rc" ]] &&
  grep -Eq "^[[:space:]]*alias[[:space:]]+codex=['\"]codex-worktree['\"]" "$shell_rc"; then
  printf 'Unmanaged codex alias still exists in %s; remove it manually if desired.\n' "$shell_rc"
fi
