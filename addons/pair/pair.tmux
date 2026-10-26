#!/usr/bin/env bash
# Load the pair addon: hooks that make a paired nvim server follow tmux. Binds no keys.
set -euo pipefail
pair="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/pair"
tmux set-hook -g 'client-session-changed[90]' "run-shell -b \"'$pair' follow '#{hook_client}'\""
tmux set-hook -g 'session-window-changed[90]' "run-shell -b \"'$pair' follow-session '#{hook_session}'\""
tmux set-hook -g 'client-detached[90]' "run-shell -b \"'$pair' forget '#{hook_client}'\""
