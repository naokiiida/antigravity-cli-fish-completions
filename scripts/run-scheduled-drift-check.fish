#!/usr/bin/env fish
#
# Dedicated runner for macOS launchd recurring upstream release & drift check.
# Sets explicit PATH, navigates to repository root, outputs timestamps,
# runs the check suite, and propagates child exit statuses.

set -l script_dir (status dirname)
set -l repo_root (builtin realpath "$script_dir/..")

# Set explicit PATH including Homebrew, Nix profiles, system paths
set -gx PATH /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /usr/bin /bin /usr/sbin /sbin /run/current-system/sw/bin $HOME/.nix-profile/bin $PATH

cd "$repo_root"

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Starting Upstream Release & Drift Check ==="

# Run upstream release check with changelog and local drift detection
fish "$repo_root/scripts/check-upstream-release.fish" -c -d
set -l check_status $status

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Completed with exit status $check_status ==="

exit $check_status
