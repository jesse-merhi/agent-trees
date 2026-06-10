#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bin_dir="${AGENT_TREES_BIN_DIR:-$HOME/.local/bin}"
shell_rc="${AGENT_TREES_SHELL_RC:-$HOME/.zshrc}"
target="$bin_dir/agent-trees"

mkdir -p "$bin_dir"
install -m 0755 "$repo_root/bin/agent-trees" "$target"

for obsolete in "$bin_dir/codex-worktree" "$bin_dir/codex-worktree-cleanup" "$bin_dir/sidegrove"; do
  if [[ -e "$obsolete" ]]; then
    rm -f "$obsolete"
    printf 'Removed obsolete %s\n' "$obsolete"
  fi
done

obsolete_state_file="$HOME/.local/state/worktree-launcher/worktrees.tsv"
if [[ -f "$obsolete_state_file" ]]; then
  rm -f "$obsolete_state_file"
  printf 'Removed obsolete %s\n' "$obsolete_state_file"
fi

if [[ ! -e "$shell_rc" ]]; then
  touch "$shell_rc"
fi

strip_block() {
  local marker="$1"
  local tmp_file

  if grep -Fq "# >>> $marker >>>" "$shell_rc"; then
    tmp_file="$(mktemp)"
    awk -v start="# >>> $marker >>>" -v end="# <<< $marker <<<" '
      $0 == start { in_block = 1; next }
      $0 == end { in_block = 0; next }
      !in_block { print }
    ' "$shell_rc" > "$tmp_file"
    mv "$tmp_file" "$shell_rc"
  fi
}

strip_block worktree-launcher
strip_block sidegrove
strip_block agent-trees

# A leftover alias pointing at an old name of this tool is ours to
# replace; the managed block below is appended later in the file, so it
# wins over the stale line.
has_foreign_alias() {
  grep -Eq "^[[:space:]]*alias[[:space:]]+$1=" "$shell_rc" &&
    ! grep -Eq "^[[:space:]]*alias[[:space:]]+$1=['\"](codex-worktree|sidegrove)" "$shell_rc"
}

aliases=()
for cli_name in codex claude; do
  if has_foreign_alias "$cli_name"; then
    printf 'Existing %s alias found in %s; leaving it in place.\n' "$cli_name" "$shell_rc"
  else
    aliases+=("$cli_name")
  fi
done

if [[ "${#aliases[@]}" -gt 0 ]]; then
  {
    printf '\n# >>> agent-trees >>>\n'
    printf 'if command -v agent-trees >/dev/null 2>&1; then\n'
    for cli_name in "${aliases[@]}"; do
      printf "  if command -v %s >/dev/null 2>&1; then\n" "$cli_name"
      printf "    alias %s='agent-trees %s'\n" "$cli_name" "$cli_name"
      printf '  fi\n'
    done
    printf 'fi\n# <<< agent-trees <<<\n'
  } >> "$shell_rc"
  printf 'Added shell alias block to %s\n' "$shell_rc"
fi

printf 'Installed %s\n' "$target"
printf 'Restart your shell or run: source %s\n' "$shell_rc"
