#!/usr/bin/env fish
#
# Check upstream releases and changelogs for Google Antigravity CLI (agy).
# Compares current tracked version in `agy-version` against upstream GitHub releases.
#
# Primary: Uses GitHub CLI (`gh`) API.
# Fallback: Uses GitHub REST API / raw.githubusercontent.com via `curl`.
#
# Usage:
#   fish scripts/check-upstream-release.fish [OPTIONS]
#
# Options:
#   -c, --changelog    Display changelog / release notes for the latest release
#   -d, --drift        Also run drift-check.fish against installed agy CLI
#   -q, --quiet        Quiet mode: exit 0 if up to date, 1 if new release available
#   -h, --help         Show help
#
# Exit codes:
#   0 - Up to date (or only info)
#   1 - New upstream release available / drift detected
#   2 - Network or API error

set -l script_dir (status dirname)
set -l repo_root (builtin realpath "$script_dir/..")
set -l version_file "$repo_root/agy-version"
set -l upstream_repo google-antigravity/antigravity-cli

set -l show_changelog 0
set -l run_drift 0
set -l quiet 0

for arg in $argv
    switch $arg
        case -c --changelog
            set show_changelog 1
        case -d --drift
            set run_drift 1
        case -q --quiet
            set quiet 1
        case -h --help
            echo "Usage: fish scripts/check-upstream-release.fish [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --changelog    Display changelog / release notes for latest release"
            echo "  -d, --drift        Also run drift-check.fish against local agy"
            echo "  -q, --quiet        Exit code only (0 = up to date, 1 = new release available)"
            echo "  -h, --help         Show this message"
            exit 0
        case '*'
            echo "Unknown option: $arg" >&2
            exit 2
    end
end

if not test -f "$version_file"
    echo "ERROR: Version file not found at $version_file" >&2
    exit 2
end

set -l current_version (string trim (cat "$version_file"))
if test -z "$current_version"
    echo "ERROR: Current version in $version_file is empty" >&2
    exit 2
end

# Fetch latest release info
set -l latest_tag ""
set -l release_title ""
set -l published_at ""
set -l release_notes ""

if command -q gh
    set -l release_json (gh release view -R "$upstream_repo" --json tagName,name,publishedAt,body 2>/dev/null)
    if test $status -eq 0 -a -n "$release_json"
        set latest_tag (string match -rg '"tagName":\s*"([^"]+)"' -- $release_json)
        set release_title (string match -rg '"name":\s*"([^"]+)"' -- $release_json)
        set published_at (string match -rg '"publishedAt":\s*"([^"]+)"' -- $release_json)
        # Extract body (handling escaped newlines)
        set release_notes (string match -rg '"body":\s*"(.*)"' -- (string replace -a '\n' "\n" -- $release_json))
    end
end

# Fallback to curl if gh failed or unavailable
if test -z "$latest_tag"
    if command -q curl
        set -l api_res (curl -sS -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$upstream_repo/releases/latest" 2>/dev/null)
        if test $status -eq 0 -a -n "$api_res"
            set latest_tag (string match -rg '"tag_name":\s*"([^"]+)"' -- $api_res)
            set release_title (string match -rg '"name":\s*"([^"]+)"' -- $api_res)
            set published_at (string match -rg '"published_at":\s*"([^"]+)"' -- $api_res)
        end
    end
end

if test -z "$latest_tag"
    if test $quiet -eq 0
        echo "ERROR: Unable to fetch latest release from $upstream_repo (check internet or GitHub rate limit)" >&2
    end
    exit 2
end

# Strip leading 'v' if present for comparison
set -l clean_latest (string replace -r '^v' '' -- $latest_tag)
set -l clean_current (string replace -r '^v' '' -- $current_version)

set -l has_new_release 0
if test "$clean_latest" != "$clean_current"
    set has_new_release 1
end

if test $quiet -eq 0
    echo "Current completions version : $clean_current"
    echo "Latest upstream release    : $clean_latest ($published_at)"
    echo "Upstream URL               : https://github.com/$upstream_repo/releases/tag/$latest_tag"
    echo ""
end

if test $has_new_release -eq 1
    if test $quiet -eq 0
        echo "🚨 NEW UPSTREAM RELEASE DETECTED: $clean_latest (current: $clean_current)"
        echo ""
    end
else
    if test $quiet -eq 0
        echo "✅ Completions are synced with latest release ($clean_current)."
        echo ""
    end
end

if test $show_changelog -eq 1
    echo "--- Upstream Release Notes / Changelog ($clean_latest) ---"
    if command -q gh
        gh release view "$latest_tag" -R "$upstream_repo" 2>/dev/null
    else if command -q curl
        # Fallback: grab latest section from CHANGELOG.md
        curl -sS "https://raw.githubusercontent.com/$upstream_repo/main/CHANGELOG.md" 2>/dev/null | head -n 35
    end
    echo ""
end

set -l drift_exit 0
if test $run_drift -eq 1
    echo "Running local drift detection..."
    fish "$repo_root/scripts/drift-check.fish"
    set drift_exit $status
end

if test $has_new_release -eq 1; or test $drift_exit -ne 0
    exit 1
end

exit 0
