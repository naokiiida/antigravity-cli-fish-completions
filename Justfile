# antigravity-cli-fish-completions Justfile
# Quick tasks for testing, drift detection, formatting, and local installation.

set shell := ["bash", "-uo", "pipefail", "-c"]

default: test

# Run offline static verification tests (14 tests)
test:
    fish scripts/verify-completions.fish

# Run bidirectional drift check against installed agy CLI
drift:
    fish scripts/drift-check.fish

# Check upstream GitHub releases for agy CLI updates
release:
    fish scripts/check-upstream-release.fish

# Fetch and display latest upstream changelog
changelog:
    fish scripts/check-upstream-release.fish -c

# Run all verification suites (test + drift + upstream release check)
all: test drift release

# Format completions and scripts using fish_indent
fmt:
    fish_indent -w completions/*.fish scripts/*.fish

# Symlink completions into user config (~/.config/fish/completions)
install:
    mkdir -p ~/.config/fish/completions
    ln -sf "$(pwd)/completions/agy.fish" ~/.config/fish/completions/agy.fish
    ln -sf "$(pwd)/completions/antigravity.fish" ~/.config/fish/completions/antigravity.fish
    @echo "Installed agy and antigravity completions to ~/.config/fish/completions/"
