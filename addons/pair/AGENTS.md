# AGENTS.md

- The command line of `scripts/pair` and the options `@repo`, `@worktree`, `@pair-<client>` and `@pair-agent` are a contract with the zerodawn-nvim addon `pair`. Add; do not change or remove.
- Read user options with `show-option -t <id>` or `of_client`, not in a `list-*` format or with `display-message -p -c`: tmux 3.7 gives the wrong item there.
- Each side does nothing when it is already at the target. Keep that: it stops loops between tmux hooks and nvim `DirChanged`.
- `tests/pair_test.sh` attaches real clients with `script` and uses a headless nvim with a fake `zerodawn.pair` module.
