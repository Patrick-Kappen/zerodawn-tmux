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
export LC_ALL=C.UTF-8
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
pane="$(tmux capture-pane -p -t "$(of_client "$client" '#{window_id}')")"
grep -q '^agent-started$' <<<"$pane" || fail "open: agent not started"
grep -q 'echo agent-started' <<<"$pane" && fail "open: the agent command shows as typed keys"

# list prints the worktree windows; the agent column needs @pair-agent-process
list_out="$("$pair" list)"
grep -qP "^\Q$repo/.git\E\t\Q$feat\E\t@[0-9]+\t0$" <<<"$list_out" || fail "list: feat window: $list_out"
tmux set-option -g @pair-agent-process sleep
tmux new-window -d -t repo: -n agent "sleep 60"
tmux set-option -w -t repo:agent @worktree /agent
for _ in $(seq 50); do
  [[ "$(tmux display-message -p -t repo:agent '#{pane_current_command}')" == sleep ]] && break
  sleep 0.1
done
list_out="$("$pair" list)"
grep -qP "\t/agent\t@[0-9]+\t1$" <<<"$list_out" || fail "list: agent column: $list_out"
tmux kill-window -t repo:agent

# a folder outside git gets its own session and no agent
"$pair" open "$server" "$work/plain"
[[ "$(of_client "$client" '#{session_name}')" == plain ]] || fail "plain: session name"
[[ -z "$(of_client "$client" '#{pane_start_command}')" ]] || fail "plain: the agent started outside git"

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

# tmux-resurrect hooks: keep an existing hook and append ours once
mkdir "$work/bin"
cat >"$work/bin/pi" <<EOF
#!$(command -v bash)
printf '%s\\n' "\$*" >> "$work/pi-args"
exec sleep 60
EOF
chmod +x "$work/bin/pi"
export PATH="$work/bin:$PATH"
tmux set-environment -g PATH "$PATH"
tmux set-environment -t repo PATH "$PATH"
tmux set-option -g @resurrect-hook-post-save-all 'true'
tmux run-shell "$here/pair.tmux"
tmux run-shell "$here/pair.tmux"
value="$(tmux show-option -gqv @resurrect-hook-post-save-all)"
grep -q "'$pair' save-sessions" <<<"$value" || fail "resurrect save hook: '$value' has no pair command"
grep -q '^true; ' <<<"$value" || fail "resurrect save hook dropped the existing hook"
[[ "$(grep -o save-sessions <<<"$value" | wc -l)" -eq 1 ]] || fail "resurrect save hook added twice"
value="$(tmux show-option -gqv @resurrect-hook-post-restore-all)"
grep -q "'$pair' restore-sessions" <<<"$value" || fail "resurrect restore hook: '$value' has no pair command"

# save: one entry for the pane that runs the agent and has a session id; no entry without an id
tmux set-option -g @pair-session-file "$work/pi-sessions"
tmux new-window -d -t repo: -n resurrect "sleep 60"
tmux set-option -w -t repo:resurrect @worktree /resurrect
for _ in $(seq 50); do
  [[ "$(tmux display-message -p -t repo:resurrect '#{pane_current_command}')" == sleep ]] && break
  sleep 0.1
done
resurrect_pane="$(tmux list-panes -t repo:resurrect -F '#{pane_id}')"
tmux set-option -p -t "$resurrect_pane" @pair-agent-session sid-123
tmux new-window -d -t repo: -n no-session "sleep 60"
tmux set-option -w -t repo:no-session @worktree /no-session
for _ in $(seq 50); do
  [[ "$(tmux display-message -p -t repo:no-session '#{pane_current_command}')" == sleep ]] && break
  sleep 0.1
done
# tmux-resurrect runs a hook with eval in bash, so the hook value must be a shell command
eval "$(tmux show-option -gqv @resurrect-hook-post-save-all)"
lines="$(wc -l <"$work/pi-sessions")"
[[ $lines -eq 1 ]] || fail "save-sessions: want one line, got $lines: $(cat "$work/pi-sessions"); panes: $(tmux list-panes -a -F '#{window_id} #{pane_current_command}')"
grep -qP "\tsid-123$" "$work/pi-sessions" || fail "save-sessions: no sid-123"
grep -q 'no-session' "$work/pi-sessions" && fail "save-sessions: saved a pane without a session id"

# restore: find the pane by the session and pane indexes when @worktree did not survive, and run pi directly
tmux set-option -wu -t repo:resurrect @worktree
eval "$(tmux show-option -gqv @resurrect-hook-post-restore-all)"
for _ in $(seq 50); do
  [[ -s $work/pi-args ]] && break
  sleep 0.1
done
args="$(<"$work/pi-args")"
[[ $args == "--session-id sid-123" ]] || fail "restore-sessions: pi got '$args', want --session-id sid-123"
sleep 0.3
pane_text="$(tmux capture-pane -p -t "$resurrect_pane")"
grep -q 'pi --session-id' <<<"$pane_text" && fail "restore-sessions: the pi command shows as typed keys"
tmux kill-window -t repo:no-session

echo ok
