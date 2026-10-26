#!/usr/bin/env bash
# Fail when an addon changed since its last tag without a higher version, or a README changelog block is stale.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
missing=()
for file in addons/*/VERSION; do
  dir="$(dirname "$file")"
  name="$(basename "$dir")"
  version="$(<"$file")"
  tag="$(git tag --list "$name-v*" --sort=-v:refname | head -n1)"
  if [[ -z $tag ]]; then
    grep -q "^## $version " "$dir/CHANGELOG.md" || missing+=("$name (new, $version has no section in its CHANGELOG.md)")
    continue
  fi
  git diff --quiet "$tag" -- "$dir" && continue
  [[ $version != "${tag#"$name-v"}" ]] || missing+=("$name (still $version, changed since $tag)")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'release-check: bump these addons with just bump-changed:\n' >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi
scripts/notes.sh
if ! git diff --quiet -- README.md addons; then
  echo "release-check: the changelog blocks in the READMEs are stale; run just notes and commit" >&2
  git checkout -q -- README.md addons
  exit 1
fi
echo "release-check: every changed addon has a new version, the README changelog blocks are current"
