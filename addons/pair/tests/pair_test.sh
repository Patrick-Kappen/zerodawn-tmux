#!/usr/bin/env bash
# Runs with its own TMUX_TMPDIR (scripts/test.sh). Needs tmux, git, nvim and script (util-linux).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
pair="$here/scripts/pair"
work="$(mktemp -d)"
trap 'kill "${nvim_pid-}" 2>/dev/null || true; pkill -P $$ sleep 2>/dev/null || true; rm -rf "$work"' EXIT
of_client() {
  local pane
  pane="$(tmux list-clients -F '#{client_name} #{pane_id}' | awk -v c="$1" '$1==c{print $2}')"
  tmux display-message -p -t "$pane" "$2"
}
fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# The nix sandbox has no TERM; a tmux client needs one.
export TERM=xterm-256color
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q -b main "$work/repo"
git -C "$work/repo" commit -q --allow-empty -m init
git -C "$work/repo" worktree add -q -b feat "$work/feat"
mkdir "$work/plain"
repo="$(cd "$work/repo" && pwd -P)"
feat="$(cd "$work/feat" && pwd -P)"

server="$work/nvim.sock"
nvim --clean --headless --listen "$server" \
  --cmd "lua package.preload['zerodawn.pair'] = function() return { follow = function(d) vim.g.followed = d; return '' end } end" &
nvim_pid=$!
for _ in $(seq 50); do
  [[ -S $server ]] && break
  sleep 0.1
done
followed() { nvim --clean --headless --server "$server" --remote-expr 'get(g:, "followed", "")'; }

tmux -f /dev/null new-session -d -s base
tmux set-option -g @pair-agent "echo agent-started"
tmux run-shell "$here/pair.tmux"

# open without a paired client exits 3
set +e
"$pair" open "$server" "$repo" 2>/dev/null
code=$?
set -e
[[ $code -eq 3 ]] || fail "open without a client: exit $code, want 3"

# attach makes the session of the repo and the window of the worktree, and registers the client
sleep 600 | script -qfc "'$pair' attach '$server' '$feat'" /dev/null >/dev/null 2>&1 &
for _ in $(seq 50); do
  [[ -n "$(tmux list-clients -F '#{client_name}')" ]] && break
  sleep 0.1
done
client="$(tmux list-clients -F '#{client_name}')"
[[ -n $client ]] || fail "attach: no client"
for _ in $(seq 50); do
  [[ -n "$(tmux show-option -gqv "@pair-$client")" ]] && break
  sleep 0.1
done
[[ "$(tmux show-option -gqv "@pair-$client")" == "$server" ]] || fail "attach: client not registered"
[[ "$(of_client "$client" '#{@repo}')" == "$repo/.git" ]] || fail "attach: @repo"
[[ "$(of_client "$client" '#{@worktree}')" == "$feat" ]] || fail "attach: @worktree"
[[ "$(of_client "$client" '#{session_name}')" == repo ]] || fail "attach: session name"

# open moves the client to the main worktree in the same session, with a new window
"$pair" open "$server" "$repo"
[[ "$(of_client "$client" '#{@worktree}')" == "$repo" ]] || fail "open: @worktree"
[[ "$(tmux list-windows -t repo | wc -l)" -eq 2 ]] || fail "open: want 2 windows in session repo"
sleep 0.5
tmux capture-pane -p -t "$(of_client "$client" '#{window_id}')" | grep -q agent-started || fail "open: agent not started"

# a folder outside git gets its own session and no agent
"$pair" open "$server" "$work/plain"
[[ "$(of_client "$client" '#{session_name}')" == plain ]] || fail "plain: session name"

# a window change in tmux makes the nvim server follow
tmux switch-client -c "$client" -t repo
for window in $(tmux list-windows -t repo -F '#{window_id}'); do
  [[ "$(tmux show-option -wqv -t "$window" @worktree)" == "$feat" ]] && tmux select-window -t "$window"
done
for _ in $(seq 50); do
  [[ "$(followed)" == "$feat" ]] && break
  sleep 0.1
done
[[ "$(followed)" == "$feat" ]] || fail "follow: nvim got '$(followed)', want $feat"

# a second pair cannot open a repo that the first pair has open
sleep 600 | script -qfc "'$pair' attach '$work/second.sock' '$work/plain'" /dev/null >/dev/null 2>&1 &
for _ in $(seq 50); do
  [[ -n "$(tmux show-option -gqv "@pair-$(tmux list-clients -t plain -F '#{client_name}' | head -n1)")" ]] && break
  sleep 0.1
done
set +e
"$pair" open "$work/second.sock" "$repo" 2>/dev/null
code=$?
set -e
[[ $code -eq 4 ]] || fail "second pair: exit $code, want 4"

# detach forgets the client
tmux detach-client -t "$client"
for _ in $(seq 50); do
  [[ -z "$(tmux show-option -gqv "@pair-$client")" ]] && break
  sleep 0.1
done
[[ -z "$(tmux show-option -gqv "@pair-$client")" ]] || fail "detach: client still registered"
echo ok
