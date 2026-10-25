#!/usr/bin/env bash
# Run the tests of one addon, or of every addon: test.sh [ADDON]. Each tests/*_test.sh runs in bash with its own tmux socket directory, so it cannot reach the tmux server of the user.
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")/.."
stop_servers() {
  local socket
  for socket in "$1"/tmux-*/*; do
    if tmux -S "$socket" has-session 2>/dev/null; then tmux -S "$socket" kill-server; fi
  done
  rm -rf "$1"
}
if [[ $# -gt 0 ]]; then
  names=("$1")
else
  names=()
  for dir in addons/*/; do names+=("$(basename "$dir")"); done
fi
if [[ ${#names[@]} -eq 0 ]]; then
  echo "test: no addons in addons/, nothing to test"
  exit 0
fi
status=0
for name in "${names[@]}"; do
  dir="$PWD/addons/$name"
  [[ -d $dir ]] || {
    echo "test: addons/$name does not exist" >&2
    exit 2
  }
  tests=("$dir"/tests/*_test.sh)
  [[ ${#tests[@]} -gt 0 ]] || {
    echo "test: addons/$name/tests has no *_test.sh; add a test" >&2
    exit 1
  }
  for file in "${tests[@]}"; do
    sockets="$(mktemp -d)"
    if env -u TMUX TMUX_TMPDIR="$sockets" bash "$file"; then
      echo "ok   addons/$name/tests/$(basename "$file")"
    else
      echo "FAIL addons/$name/tests/$(basename "$file")" >&2
      status=1
    fi
    stop_servers "$sockets"
  done
done
exit "$status"
