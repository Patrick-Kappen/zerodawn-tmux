# Open points

- Addon `pair`: a wezterm/tmux window and nvimx-gui stay on the same repo and worktree. tmux session = repo, tmux window = worktree. It works only after the pair key in nvimx or pi.
  - Command line for zerodawn-nvim and zerodawn-pi: start a pair, open a folder, follow tmux, stop a pair.
  - Pair registry in `$XDG_RUNTIME_DIR`: tmux client and nvim server of each pair. Several pairs; one pair for each repo, a second one is refused with a notification.
  - Hooks `client-session-changed` and `session-window-changed` make nvimx follow, only for a client in a pair.
  - Match sessions and windows on the options `@repo` (git common dir) and `@worktree` (worktree root), not on names.
  - A new worktree window starts pi.
- Addon `resurrect-pi`, or a part of `pair`: save and restore with tmux-resurrect.
  - Save on each change through tmux hooks; no save until a restore ran in this server.
  - zerodawn-pi sets the pane option `@pi_session`. `post-save-layout` writes the pi session of each pane next to the resurrect file. `post-restore-all` starts `pi --session-id <id>` in that pane.
  - Find `@repo` and `@worktree` again after a restore.
- tmuxw gets tmux-resurrect with its own save folder, in nixos-config.
