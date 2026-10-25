# Contributing

## Setup

`direnv allow` (or `nix develop`) gives you tmux, shellcheck, shfmt, the bash LSP, just and the nix linters, and installs the git hooks. `just check` runs everything CI runs.

## Branch and commit

- Work on a branch and open a pull request. A hook refuses commits on `main`.
- Commit subject: `<scope>: what changed`. Scope is an addon name, `release`, `ci`, `docs`, `flake`, `repo` or `deps`. At most 72 characters. A hook checks it; the subjects become the changelog.
- One concern per PR.

## Layout of an addon

`addons/<name>/` is one tmux plugin:

- `<name>.tmux`: the executable script that tmux runs with `run-shell`. It sets hooks and options, and binds no keys.
- `scripts/`: the other scripts of the addon.
- `tests/*_test.sh`: each file runs in bash with its own `TMUX_TMPDIR`. A test starts its own tmux server; a non-zero exit fails the test.
- `README.md` with the options and the commands, and `AGENTS.md` for coding agents.

`nix flake check` fails when one of these is missing.

## Checks

| Where | What |
|---|---|
| hook, commit | shellcheck, shfmt, nixfmt, statix, deadnix, gitleaks, commit subject |
| hook, push | the subject of every commit on the branch |
| PR | the commit subjects, `nix flake check` with every check and the tests of every addon |
| merge to `main` | `nix flake check`, then the release job |

## Release

Feature PRs do not change `VERSION` or `CHANGELOG.md`. When a set of changes is done:

1. Make a branch from a clean `main` and run `just release minor` (or `patch`, `major`). It writes the next version to `VERSION` and the changelog section from the commit subjects since the last tag, and commits both. The first release ships the version that is in `VERSION`.
2. Open that commit as a PR. Edit the changelog wording there if you want.
3. Merge. CI tags `v<version>` and creates the GitHub release from `CHANGELOG.md`.

## Decisions

Structural choices are in `docs/decisions.md` with a reason. Read it before you change the structure; add an entry when you do.
