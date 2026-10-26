#!/usr/bin/env bash
# Bump every addon that changed since its last tag, and the repository version; write the changelogs and commit.
# The level of each addon comes from the "Change:" trailers of its commits since its last tag:
# breaking -> major (minor below 1.0), feature -> minor, fix -> patch.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
fail() {
  printf 'bump-changed: %s\n' "$1" >&2
  exit 1
}
[[ -z "$(git status --porcelain)" ]] || fail "commit or stash your changes first"
[[ "$(git branch --show-current)" != main ]] || fail "a hook refuses commits on main; run it on a branch: git switch -c release"

rank() { case "$1" in fix) echo 1 ;; feature) echo 2 ;; breaking) echo 3 ;; esac }
# change_of RANGE [PATH]: the highest change of the non-release commits in RANGE.
change_of() {
  local range="$1" path="${2:-.}" best=fix sha change missing=()
  while IFS= read -r sha; do
    change="$(git log -1 --format=%B "$sha" | git interpret-trailers --parse | sed -n 's/^Change: //p')"
    if [[ -z $change ]]; then
      [[ "$(git log -1 --format=%s "$sha")" == release:* ]] && continue
      missing+=("$(git log -1 --format='%h %s' "$sha")")
      continue
    fi
    [[ "$(rank "$change")" -gt "$(rank "$best")" ]] && best="$change"
  done < <(git rev-list --no-merges "$range" -- "$path")
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'bump-changed: these commits have no "Change:" trailer:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    printf 'Next: reword them with a "Change: fix|feature|breaking" trailer\n' >&2
    return 1
  fi
  echo "$best"
}
next() {
  local a b c
  IFS=. read -r a b c <<<"$1"
  case "$2" in
  breaking) if [[ $a -eq 0 ]]; then echo "$a.$((b + 1)).0"; else echo "$((a + 1)).0.0"; fi ;;
  feature) echo "$a.$((b + 1)).0" ;;
  fix) echo "$a.$b.$((c + 1))" ;;
  esac
}

bumped=()
for file in addons/*/VERSION; do
  dir="$(dirname "$file")"
  name="$(basename "$dir")"
  version="$(<"$file")"
  tag="$(git tag --list "$name-v*" --sort=-v:refname | head -n1)"
  if [[ -n $tag ]] && git diff --quiet "$tag" -- "$dir"; then continue; fi
  if [[ -n $tag && $version != "${tag#"$name-v"}" ]]; then continue; fi
  # An addon without a tag ships its current version as its first release; only a released one is bumped.
  if [[ -n $tag ]]; then
    change="$(change_of "$tag..HEAD" "$dir")"
    new="$(next "$version" "$change")"
  else
    new="$version"
  fi
  bumped+=("$name $version $new $dir")
done
[[ ${#bumped[@]} -gt 0 ]] || fail "no addon changed since its last tag; nothing to release"

version="$(<VERSION)"
last="$(git tag --list 'v*' --sort=-v:refname | head -n1)"
if [[ -n $last ]]; then
  change="$(change_of "$last..HEAD")"
  new="$(next "$version" "$change")"
else
  new="$version"
fi

today="$(date +%F)"
prepend() {
  local file="$1" text="$2" tmp
  tmp="$(mktemp)"
  {
    head -n1 "$file"
    printf '\n%s\n' "$text"
    tail -n +2 "$file"
  } >"$tmp"
  mv "$tmp" "$file"
}
root="## $new — $today"
for entry in "${bumped[@]}"; do
  read -r name _ to dir <<<"$entry"
  tag="$(git tag --list "$name-v*" --sort=-v:refname | head -n1)"
  if [[ -n $tag ]]; then
    lines="$(git log --no-merges --format='- %s%x09%(trailers:key=Change,valueonly)' "$tag..HEAD" -- "$dir" |
      grep -v -e '^- release:' -e '^$' | sed "s/^- $name: /- /; s/\tbreaking$/ (breaking)/; s/\t.*$//")"
  else
    lines="- First release."
  fi
  printf '%s\n' "$to" >"$dir/VERSION"
  [[ -f "$dir/CHANGELOG.md" ]] || printf '# Changelog\n' >"$dir/CHANGELOG.md"
  prepend "$dir/CHANGELOG.md" "$(printf '## %s — %s\n\n%s' "$to" "$today" "$lines")"
  root="$(printf '%s\n\n### %s %s\n\n%s' "$root" "$name" "$to" "$lines")"
done
printf '%s\n' "$new" >VERSION
prepend CHANGELOG.md "$root"
scripts/notes.sh
git add VERSION CHANGELOG.md README.md addons
summary="$(printf '%s\n' "${bumped[@]}" | awk '{print $1, $2, "->", $3}')"
git commit -q -m "release: v$new" -m "$summary"
printf 'repository %s -> %s\n%s\n' "$version" "$new" "$summary"
echo "Next: push the branch and open a PR; CI tags the versions after the merge"
