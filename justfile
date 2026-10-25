# Run the tests of every addon, or of one: just test <addon>
test addon="":
    scripts/test.sh {{addon}}

# Lint and check the format of every shell file
lint:
    shfmt -f . | xargs shellcheck
    shfmt -d -s -i 2 .

# Format the Nix and shell files with treefmt
fmt:
    nix fmt

# Run every check: lint, tests, nix flake check
check: lint test
    nix flake check

# Write the next version and its changelog section and commit both, on a branch: just release minor|patch|major
release level="minor":
    scripts/release.sh {{level}}
