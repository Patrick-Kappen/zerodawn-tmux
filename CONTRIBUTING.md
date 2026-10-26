# Contributing

## Setup

`direnv allow` (or `nix develop`) gives you tmux, shellcheck, shfmt, the bash LSP, just and the nix linters, and installs the git hooks. `just check` runs everything CI runs.

## Branch and commit

- Work on a branch and open a pull request. A hook refuses commits on `main`.
- Commit subject: `<scope>: what changed`. Scope is an addon name, `release`, `ci`, `docs`, `flake`, `repo` or `deps`. At most 72 characters. A hook checks it; the subjects become the changelog.
- Add one trailer line after a blank line: `Change: fix` (no new behaviour: bug fix, docs, refactor, tests, CI), `Change: feature` (new behaviour that keeps old use) or `Change: breaking` (old use stops working). It sets the version level.
- One concern per PR.

## Layout of an addon

`addons/<name>/` is one tmux plugin:

- `<name>.tmux`: the executable script that tmux runs with `run-shell`. It sets hooks and options, and binds no keys.
- `scripts/`: the other scripts of the addon.
- `tests/*_test.sh`: each file runs in bash with its own `TMUX_TMPDIR`. A test starts its own tmux server; a non-zero exit fails the test.
- `VERSION` (the first one, for example `0.1.0`) and `CHANGELOG.md` (the line `# Changelog`); a release writes both after that.
- `README.md` with the options and the commands, and `AGENTS.md` for coding agents.

`nix flake check` fails when one of these is missing.

## Checks

| Where | What |
|---|---|
| hook, commit | shellcheck, shfmt, nixfmt, statix, deadnix, gitleaks, commit subject |
| hook, push | the subject of every commit on the branch |
| PR | the commit subjects and trailers; `release-check` on a PR with a `release:` title; `nix flake check` with every check and the tests of every addon |
| merge to `main` | `nix flake check`, then the release job |

## Release

Each addon has its own version, in `addons/<name>/VERSION`, and its own `CHANGELOG.md`. The repository has a version too, in `VERSION`. Feature PRs do not change them. When a set of changes is done:

1. Make a branch from a clean `main` and run `just bump-changed`. For every addon that changed since its last tag, it picks the level from the `Change:` trailers (breaking: major, or minor below 1.0; feature: minor; fix: patch). It writes the versions and the changelog sections from the commit subjects, bumps the repository version, refreshes the README blocks, and commits. An addon without a tag ships its current version as its first release.
2. Open that commit as a PR with the `release: v<version>` title. Edit the changelog wording there if you want. CI runs `release-check`.
3. Merge. CI tags `<addon>-v<version>` for every new addon version and `v<version>` for the repository, and creates the GitHub release from `CHANGELOG.md`.

A flake ref can pin either tag: `github:Patrick-Kappen/zerodawn-tmux/<addon>-v<version>` or `.../v<version>`.

## Decisions

Structural choices are in `docs/decisions.md` with a reason. Read it before you change the structure; add an entry when you do.
