#!/usr/bin/env bash
# After a merge to main: tag every new addon version and the repository version, and create the GitHub release.
# Needs GH_TOKEN and push rights.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
fail() {
  printf 'ci-release: %s\n' "$1" >&2
  [[ $# -gt 1 ]] && printf 'Next: %s\n' "$2" >&2
  exit 1
}
[[ -n ${GH_TOKEN:-} ]] || fail "GH_TOKEN is not set" "give the release job the GitHub token with contents: write"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git fetch -q --tags origin || fail "cannot fetch tags from origin" "check the token and the remote"
# section FILE VERSION: the changelog section of VERSION, without its heading.
section() { awk -v v="$2" '/^## /{p=($2==v)} p && !/^## /' "$1"; }
tag_it() {
  local tag="$1" notes="$2"
  git tag -a "$tag" -m "$tag" -m "$notes" || fail "cannot create tag $tag" "look for a tag with the same name: git tag -l '$tag*'"
  git push origin "$tag" || fail "cannot push tag $tag" "check the branch protection and the token scope (contents: write)"
  echo "tagged $tag"
}
tagged=0
for file in addons/*/VERSION; do
  dir="$(dirname "$file")"
  name="$(basename "$dir")"
  version="$(<"$file")"
  tag="$name-v$version"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null && continue
  notes="$(section "$dir/CHANGELOG.md" "$version")"
  if [[ -z $notes ]]; then
    echo "$tag: no changelog section, not released"
    continue
  fi
  tag_it "$tag" "$notes"
  tagged=$((tagged + 1))
done
version="$(<VERSION)"
tag="v$version"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "$tag exists: no repository release ($tagged new addon tags)"
  exit 0
fi
notes="$(section CHANGELOG.md "$version")"
if [[ -z $notes ]]; then
  echo "$tag: no changelog section in CHANGELOG.md, not released ($tagged addon tags)"
  exit 0
fi
untagged=()
for file in addons/*/VERSION; do
  t="$(basename "$(dirname "$file")")-v$(<"$file")"
  git rev-parse -q --verify "refs/tags/$t" >/dev/null || untagged+=("$t")
done
[[ ${#untagged[@]} -eq 0 ]] || fail "$tag would ship addons without a tag: ${untagged[*]}" \
  "give each one a changelog section for its version (just bump-changed), merge, and the next run tags it"
tag_it "$tag" "$notes"
gh release create "$tag" --title "$tag" --notes "$notes" ||
  fail "tag $tag is pushed but the GitHub release was not created" "create it by hand: gh release create $tag --title $tag --notes-file FILE"
echo "released $tag with $tagged addon tags"
