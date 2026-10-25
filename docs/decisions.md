# Decisions

Short records of choices that shape the repository. Newest at the top.

## 3. One version for the repository (2026-10-25)

`VERSION` and `CHANGELOG.md` cover all addons, and the tags are `v<version>`. Reason: nixos-config pins one tag, and a version for each addon adds release work that has no user now. Add versions for each addon when an addon gets users outside nixos-config.

## 2. An addon binds no keys (2026-10-25)

An addon sets hooks and options, and gives commands. The tmux config binds the keys to these commands. Reason: keys are personal and change often, and the addon stays usable in another config.

## 1. Addons here, the config in nixos-config (2026-10-25)

This repository holds addons only: code that does one task and has tests. The tmuxw config (options, plugin choice, keys) stays in nixos-config. Reason: the same split as zerodawn-pi and pi. Addons get versions, tests and CI, and the config stays quick to change.
