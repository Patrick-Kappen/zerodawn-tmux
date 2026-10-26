#!/usr/bin/env bash
# Write the newest changelog sections into the README of each addon and of the repository.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
# section FILE N: the first N "## " sections of a changelog, without the title line.
section() { awk -v n="$2" '/^## /{c++} c>=1 && c<=n' "$1"; }
# block FILE TEXT: replace the text between the changelog markers in FILE, or add the block at the end.
block() {
  local file="$1" text="$2" tmp
  tmp="$(mktemp)"
  if grep -q '<!-- changelog:start -->' "$file"; then
    awk -v text="$text" '
      /<!-- changelog:start -->/ { print; print text; skip=1; next }
      /<!-- changelog:end -->/ { skip=0 }
      !skip' "$file" >"$tmp"
  else
    {
      cat "$file"
      printf '\n## Changes\n\n<!-- changelog:start -->\n%s\n<!-- changelog:end -->\n' "$text"
    } >"$tmp"
  fi
  mv "$tmp" "$file"
}
for file in addons/*/VERSION; do
  dir="$(dirname "$file")"
  [[ -f "$dir/CHANGELOG.md" ]] || printf '# Changelog\n' >"$dir/CHANGELOG.md"
  text="$(section "$dir/CHANGELOG.md" 1)"
  [[ -n $text ]] || text="No release yet."
  block "$dir/README.md" "$(printf '%s\n\n[All changes](CHANGELOG.md)' "$text")"
done
text="$(section CHANGELOG.md 3)"
[[ -n $text ]] || text="No release yet."
block README.md "$(printf '%s\n\n[All changes](CHANGELOG.md)' "$text")"
