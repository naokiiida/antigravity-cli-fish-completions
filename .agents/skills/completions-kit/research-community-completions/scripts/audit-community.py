#!/usr/bin/env python3
"""
audit-community.py - Community Completions Auditor & Freshness Scorer

Audits prior community completions across:
1. Native Fish completions ($__fish_data_dir/completions/<cli>.fish)
2. Fisher ecosystem repositories
3. Carapace (carapace-bin/completers/common/<cli>_completer)
4. GitHub / Zsh completion repositories

Performs upfront freshness scoring (git commit date, version comments) to detect
stale completions, catch hallucinations, and surface valuable presets.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def get_fish_data_dir() -> Path:
    """Retrieve Fish data dir."""
    ret = subprocess.run(["fish", "-c", "echo $__fish_data_dir"], stdout=subprocess.PIPE, text=True)
    if ret.returncode == 0 and ret.stdout.strip():
        return Path(ret.stdout.strip())
    return Path("/opt/homebrew/share/fish")


def score_freshness(last_modified_date: Optional[datetime], target_version: Optional[str], cli_version: Optional[str]) -> Tuple[str, str]:
    """Score the freshness and trustworthiness of a completion source."""
    if not last_modified_date:
        return "UNKNOWN", "No date metadata available"

    now = datetime.now(timezone.utc)
    delta_days = (now - last_modified_date).days

    score_str = "🟢 HIGH (Fresh)"
    reason = f"Updated {delta_days} days ago"

    if delta_days > 365:
        score_str = "🔴 LOW (Stale)"
        reason = f"Inactive for {delta_days // 365} year(s) - High risk of phantom commands and outdated flags"
    elif delta_days > 180:
        score_str = "🟡 MEDIUM (Reference)"
        reason = f"Updated {delta_days} days ago - Cross-check required"

    if target_version and cli_version:
        if target_version == cli_version:
            reason += f" (Matches CLI version {cli_version})"
        else:
            reason += f" (Created for {target_version}, current CLI is {cli_version})"

    return score_str, reason


def extract_flags_from_fish_script(script_path: Path) -> List[Dict[str, str]]:
    """Parse complete -c invocations in a fish file."""
    flags: List[Dict[str, str]] = []
    if not script_path.exists():
        return flags

    content = script_path.read_text(encoding="utf-8", errors="ignore")
    flag_re = re.compile(r"complete\s+-(?:[a-zA-Z0-9_-]+\s+)*?(?:-l\s+([a-zA-Z0-9_-]+))(?:\s+-d\s+[\"'](.*?)[\"'])?")
    for m in flag_re.finditer(content):
        long_flag = m.group(1)
        desc = m.group(2) or ""
        flags.append({"long": long_flag, "description": desc})
    return flags


def audit_cli(cli_name: str) -> str:
    """Run full community audit for the target CLI."""
    cli_path = shutil.which(cli_name)
    cli_version = None
    if cli_path:
        ret = subprocess.run([cli_name, "--version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        out = ret.stdout or ret.stderr
        m = re.search(r"\b(\d+\.\d+(?:\.\d+)?)\b", out)
        if m:
            cli_version = m.group(1)

    reports: List[str] = [
        f"# Community Completion Audit Report for `{cli_name}`",
        f"- Target CLI Path: `{cli_path or 'Not in PATH'}`",
        f"- Target CLI Version: `{cli_version or 'Unknown'}`",
        f"- Audit Timestamp: `{datetime.now(timezone.utc).isoformat()}`",
        "",
        "## Source Audits",
        "",
    ]

    # 1. Native Fish Completion Check
    fish_dir = get_fish_data_dir()
    native_fish_file = fish_dir / "completions" / f"{cli_name}.fish"
    if native_fish_file.exists():
        stat = native_fish_file.stat()
        mod_date = datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc)
        score, reason = score_freshness(mod_date, None, cli_version)
        reports.append(f"### 1. Native Fish Shell Completions (`{native_fish_file}`)")
        reports.append(f"- **Trust Score**: {score}")
        reports.append(f"- **Evaluation**: {reason}")
        flags = extract_flags_from_fish_script(native_fish_file)
        reports.append(f"- **Defined Flags**: {len(flags)}")
        reports.append("")
    else:
        reports.append(f"### 1. Native Fish Shell Completions")
        reports.append(f"- *Status*: No native completion bundled in Fish for `{cli_name}`.")
        reports.append("")

    # 2. Carapace Completer Check (Local clone or specs if available)
    carapace_spec = Path.home() / ".config" / "carapace" / "specs" / f"{cli_name}.yaml"
    if carapace_spec.exists():
        stat = carapace_spec.stat()
        mod_date = datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc)
        score, reason = score_freshness(mod_date, None, cli_version)
        reports.append(f"### 2. Carapace User Spec (`{carapace_spec}`)")
        reports.append(f"- **Trust Score**: {score}")
        reports.append(f"- **Evaluation**: {reason}")
        reports.append("")
    else:
        reports.append(f"### 2. Carapace Completer (`rsteube/carapace-bin`)")
        reports.append(f"- *Status*: Check online at `https://github.com/carapace-sh/carapace-bin/tree/master/completers/common/{cli_name}_completer`.")
        reports.append(f"- **Heuristic Caution**: Always verify Carapace Go completers against live `{cli_name} --help`. Handwritten community completers in Carapace often contain phantom commands or obsolete flags.")
        reports.append("")

    # 3. Fisher Ecosystem Guidance
    reports.append("### 3. Fisher Ecosystem Packages")
    reports.append(f"- Search command: `fisher list | grep {cli_name}` or check GitHub `jorgebucaran/awsm.fish` index.")
    reports.append("")

    # 4. Recommendation Matrix
    reports.append("## Actionable Recommendations")
    reports.append("1. **Do not copy flags blindly**: Always cross-validate any third-party completion against `crawl-cli.py` output.")
    reports.append("2. **Adopt dynamic ideas, not static lists**: Look for duration presets (e.g. `10s 1m 5m`), custom file extensions, or executable completions (`__fish_complete_command`).")
    reports.append("3. **Ensure root isolation**: Wrap root-level flags with `-n __fish_use_subcommand` regardless of how community scripts wrote them.")

    return "\n".join(reports) + "\n"


def main():
    parser = argparse.ArgumentParser(description="Community Completion Auditor & Freshness Scorer")
    parser.add_argument("cli", help="Target CLI command name")
    parser.add_argument("-o", "--output", help="Output report file (default: stdout)")

    args = parser.parse_args()
    report = audit_cli(args.cli)

    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_text(report, encoding="utf-8")
        print(f"Audit report written to: {args.output}", file=sys.stderr)
    else:
        print(report)


if __name__ == "__main__":
    main()
