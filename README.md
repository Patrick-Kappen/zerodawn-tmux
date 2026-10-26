# zerodawn-tmux

Addons for tmux, in shell, as one Nix flake. Each addon is a separate tmux plugin. Your tmux config chooses the addons and binds the keys; this repository has no config.

There are no addons yet. The planned ones are in [docs/todo.md](docs/todo.md).

## Install with Nix

This repository is a flake. It exports:

| Output | What |
|---|---|
| `packages.<system>.<addon>` | the addon as a tmux plugin, without tests; `.rtp` is the path of its `<addon>.tmux` |
| `checks.<system>.*` | `pre-commit` and `tests-<addon>` |

Load the plugin in your tmux config:

```nix
run-shell ${zerodawn-tmux.packages.${system}.<addon>.rtp}
```

## Develop

`direnv allow` (or `nix develop`), then `just check`. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Changes

<!-- changelog:start -->
No release yet.

[All changes](CHANGELOG.md)
<!-- changelog:end -->
