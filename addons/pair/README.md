# pair

Keeps tmux clients and an nvim server on the same place: one tmux session for each repo, one window for each worktree. It works only for a client that a pair started; a plain tmux client does nothing.

## Load

```
run-shell ${zerodawn-tmux.packages.<system>.pair.rtp}
set -g @pair-agent pi
```

`@pair-agent`: the command that starts in a new worktree window. Empty: no command. A folder outside git never gets it.

Needs `git` and `nvim` on the PATH of the tmux server. The addon binds no keys.

## Command: `scripts/pair`

`pair [--tmux EXE] COMMAND`. `--tmux` gives your tmux wrapper, so a new server loads your config.

| Command | Use |
|---|---|
| `attach SERVER DIR` | Run in a new terminal. Opens DIR and attaches a client paired with the nvim server SERVER. |
| `open SERVER DIR` | Moves every client of SERVER to DIR. Exit 3: no client is paired. Exit 4: another pair has the repo open. |
| `follow CLIENT`, `follow-session SID` | Hooks: make the nvim server change to the worktree of the client. |
| `register CLIENT SERVER`, `forget CLIENT` | Pair and unpair a client. |

## Rules

- Sessions match on `@repo` (the git common dir), windows on `@worktree` (the worktree root). Names are only for display.
- A second pair cannot open a repo that a client of another pair shows (exit 4).
- The nvim server must have the Lua module `zerodawn.pair` with `follow(dir)`: the zerodawn-nvim addon `pair`.

## Changes

<!-- changelog:start -->
## 0.1.0 — 2026-10-26

- First release.

[All changes](CHANGELOG.md)
<!-- changelog:end -->
