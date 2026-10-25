#!/usr/bin/env bash
# After a merge to main: tag the version in VERSION and create the GitHub release. Needs GH_TOKEN and push rights.
set -euo pipefail
cd "$(dirname "$0")/.."
fail() {
  printf 'ci-release: %s\n' "$1" >&2
  printf 'Next: %s\n' "$2" >&2
  exit 1
}
[[ -n ${GH_TOKEN:-} ]] || fail "GH_TOKEN is not set" "give the release job the GitHub token with contents: write"
git fetch -q --tags origin || fail "cannot fetch tags from origin" "check the token and the remote"
version="$(<VERSION)"
tag="v$version"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "ci-release: $tag exists, no release"
  exit 0
fi
notes="$(awk -v v="$version" '/^## /{p=($2==v)} p && !/^## /' CHANGELOG.md)"
if [[ -z $notes ]]; then
  echo "ci-release: CHANGELOG.md has no section for $version, no release"
  exit 0
fi
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git tag -a "$tag" -m "$tag" -m "$notes" || fail "cannot create tag $tag" "look for a tag with the same name: git tag -l '$tag*'"
git push origin "$tag" || fail "cannot push tag $tag" "check the branch protection and the token scope (contents: write)"
gh release create "$tag" --title "$tag" --notes "$notes" ||
  fail "tag $tag is pushed but the GitHub release was not created" "create it by hand: gh release create $tag --title $tag --notes-file FILE"
echo "ci-release: released $tag"
