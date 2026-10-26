# Decisions

Short records of choices that shape the repository. Newest at the top.

## 3. A version for each addon (2026-10-26)

Each addon has `VERSION` and `CHANGELOG.md` and the tag `<addon>-v<version>`; the repository has `VERSION`, `CHANGELOG.md` and the tag `v<version>`. The version level comes from a `Change:` trailer on each commit. Reason: the same release model as zerodawn-pi, and an addon gets a new version only when it changed.

## 2. An addon binds no keys (2026-10-25)

An addon sets hooks and options, and gives commands. The tmux config binds the keys to these commands. Reason: keys are personal and change often, and the addon stays usable in another config.

## 1. Addons here, the config in nixos-config (2026-10-25)

This repository holds addons only: code that does one task and has tests. The tmuxw config (options, plugin choice, keys) stays in nixos-config. Reason: the same split as zerodawn-pi and pi. Addons get versions, tests and CI, and the config stays quick to change.
