# AGENTS.md

tmux addons in shell. Nix flake with one tmux plugin package for each addon.

## Layout

- `addons/<name>/`: one addon, a tmux plugin. Entry `<name>.tmux` (executable, run by `run-shell`), other scripts in `scripts/`. Tests in `tests/*_test.sh`; `scripts/test.sh` gives each test its own `TMUX_TMPDIR`, so a test cannot reach the tmux server of the user. Every addon has `README.md`, `AGENTS.md` and at least one test; the flake fails without them.
- `docs/decisions.md`: why things are the way they are. Read it before a structural change; add a numbered entry when you make one.
- `docs/todo.md` is the owner's notes. Do not act on it unless asked.

## Rules

- This repository holds addons, not a config. The tmux (tmuxw) config that loads them is in the owner's nixos-config. An addon binds no keys; the config binds them.
- The command line of an addon is a contract with zerodawn-nvim and zerodawn-pi. Do not change or remove a command or an option; add a new one.
- Commit subject: `<scope>: what changed`, scope is an addon name, `release`, `ci`, `docs`, `flake`, `repo` or `deps`. Max 72 characters. The subjects become the changelog.
- Work on a branch and worktree add ~/.worktrees and open a PR; `main` is protected by a hook.
- Do not edit `CHANGELOG.md` or `VERSION` by hand. A release is `just release <level>` on a branch, as its own PR.
- Do not add a dependency without an entry in `docs/decisions.md`.
- Fail loud: no fallback that hides a missing input. Errors name the file or the id and the next step.
- No comments except for a reason the code cannot show. English everywhere.

## Checks

- `just check`: shellcheck, shfmt, the tests, `nix flake check`.
- `just test [addon]` and `just lint` for one part.
