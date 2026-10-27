#!/usr/bin/env bash
# Load the pair addon: hooks that make a paired nvim server follow tmux. Binds no keys.
set -euo pipefail
pair="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/pair"
tmux set-hook -g 'client-session-changed[90]' "run-shell -b \"'$pair' follow '#{hook_client}'\""
tmux set-hook -g 'session-window-changed[90]' "run-shell -b \"'$pair' follow-session '#{hook_session}'\""
tmux set-hook -g 'client-detached[90]' "run-shell -b \"'$pair' forget '#{hook_client}'\""

# tmux-resurrect runs these options after its save and restore. Keep an existing hook and add ours once.
add_resurrect_hook() {
  local name="$1" command current
  command="run-shell -b \"'$pair' $2\""
  current="$(tmux show-option -gqv "@resurrect-hook-$name" 2>/dev/null || true)"
  [[ $current == *"'$pair' $2"* ]] && return 0
  tmux set-option -g "@resurrect-hook-$name" "${current:+$current; }$command"
}
add_resurrect_hook post-save-all save-sessions
add_resurrect_hook post-restore-all restore-sessions
