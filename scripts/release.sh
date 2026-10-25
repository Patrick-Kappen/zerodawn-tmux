#!/usr/bin/env bash
# Write the next version to VERSION and its changelog section from the commit subjects, and commit both.
# Usage: release.sh major|minor|patch. CI tags the version after the merge to main.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() {
  printf 'release: %s\n' "$1" >&2
  exit 1
}
level="${1:?usage: release.sh major|minor|patch}"
case "$level" in major | minor | patch) ;; *) fail "the level must be major, minor or patch, got: $level" ;; esac
[[ -z "$(git status --porcelain)" ]] || fail "commit or stash your changes first"
[[ "$(git branch --show-current)" != main ]] || fail "a hook refuses commits on main; run it on a branch: git switch -c release"
version="$(<VERSION)"
tag="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
next() {
  IFS=. read -r a b c <<<"$1"
  case "$level" in
  major) echo "$((a + 1)).0.0" ;;
  minor) echo "$a.$((b + 1)).0" ;;
  patch) echo "$a.$b.$((c + 1))" ;;
  esac
}
if [[ -z $tag ]]; then
  # The first release ships the version that is in VERSION; the level applies from the second release.
  new="$version"
  lines="- First release."
else
  [[ $version == "${tag#v}" ]] || fail "VERSION is $version but the last tag is $tag; set VERSION back to ${tag#v}"
  lines="$(git log --no-merges --format='- %s' "$tag..HEAD")"
  [[ -n $lines ]] || fail "no commits since $tag; nothing to release"
  new="$(next "$version")"
fi
printf '%s\n' "$new" >VERSION
tmp="$(mktemp)"
{
  head -n1 CHANGELOG.md
  printf '\n## %s — %s\n\n%s\n' "$new" "$(date +%F)" "$lines"
  tail -n +2 CHANGELOG.md
} >"$tmp"
mv "$tmp" CHANGELOG.md
git add VERSION CHANGELOG.md
git commit -q -m "release: v$new"
echo "release: committed v$new; push the branch and open a PR, CI tags v$new after the merge"
