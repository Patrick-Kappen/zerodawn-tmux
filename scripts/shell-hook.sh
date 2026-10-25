#!/usr/bin/env bash
# Runs when the dev shell starts: installs the git hooks.
set -euo pipefail
# The global git config can set core.hooksPath, and pre-commit refuses to install while it is set.
GIT_CONFIG_GLOBAL=/dev/null bash -c "${PRE_COMMIT_SHELL_HOOK:?set by flake.nix}"
