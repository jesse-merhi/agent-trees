#!/usr/bin/env bash
set -euo pipefail

# Works from a clone (./scripts/install.sh) and piped from the web
# (curl ... | bash). AGENT_TREES_RAW_BASE exists so the tests can point
# the piped path at a local file:// URL.
raw_base="${AGENT_TREES_RAW_BASE:-https://raw.githubusercontent.com/jesse-merhi/agent-trees/main}"
bin_dir="${AGENT_TREES_BIN_DIR:-$HOME/.local/bin}"
shell_rc="${AGENT_TREES_SHELL_RC:-$HOME/.zshrc}"
target="$bin_dir/agent-trees"

script_source="${BASH_SOURCE[0]:-}"
local_binary=""
if [[ -n "$script_source" && -f "$script_source" ]]; then
  local_binary="$(cd "$(dirname "$script_source")/.." && pwd -P)/bin/agent-trees"
fi

mkdir -p "$bin_dir"

if [[ -n "$local_binary" && -f "$local_binary" ]]; then
  install -m 0755 "$local_binary" "$target"
else
  tmp_file="$(mktemp)"
  if ! curl -fsSL "$raw_base/bin/agent-trees" -o "$tmp_file"; then
    printf 'agent-trees: download failed: %s\n' "$raw_base/bin/agent-trees" >&2
    rm -f "$tmp_file"
    exit 1
  fi
  if ! head -n 1 "$tmp_file" | grep -q '^#!'; then
    printf 'agent-trees: %s/bin/agent-trees does not look like a script; aborting\n' "$raw_base" >&2
    rm -f "$tmp_file"
    exit 1
  fi
  install -m 0755 "$tmp_file" "$target"
  rm -f "$tmp_file"
fi

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
