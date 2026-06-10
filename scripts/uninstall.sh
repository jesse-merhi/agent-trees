#!/usr/bin/env bash
set -euo pipefail

bin_dir="${SIDEGROVE_BIN_DIR:-$HOME/.local/bin}"
shell_rc="${SIDEGROVE_SHELL_RC:-$HOME/.zshrc}"

for target in "$bin_dir/sidegrove" "$bin_dir/codex-worktree" "$bin_dir/codex-worktree-cleanup"; do
  if [[ -e "$target" ]]; then
    rm -f "$target"
    printf 'Removed %s\n' "$target"
  fi
done

strip_block() {
  local marker="$1"
  local tmp_file

  if [[ -e "$shell_rc" ]] && grep -Fq "# >>> $marker >>>" "$shell_rc"; then
    tmp_file="$(mktemp)"
    awk -v start="# >>> $marker >>>" -v end="# <<< $marker <<<" '
      $0 == start { in_block = 1; next }
      $0 == end { in_block = 0; next }
      !in_block { print }
    ' "$shell_rc" > "$tmp_file"
    mv "$tmp_file" "$shell_rc"
    printf 'Removed %s shell block from %s\n' "$marker" "$shell_rc"
  fi
}

strip_block worktree-launcher
strip_block sidegrove

if [[ -e "$shell_rc" ]] &&
  grep -Eq "^[[:space:]]*alias[[:space:]]+(codex|claude)=['\"]sidegrove" "$shell_rc"; then
  printf 'Unmanaged sidegrove alias still exists in %s; remove it manually if desired.\n' "$shell_rc"
fi
