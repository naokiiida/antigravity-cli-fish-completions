#!/usr/bin/env python3
"""
crawl-cli.py - Universal CLI Tree Crawler & Spec Extractor

Dual-channel discovery:
1. Help crawling & framework introspection (--help, -h, __complete, _*_COMPLETE)
2. Static binary inspection (strings extraction, hidden flag probing, env var discovery)

Outputs a canonical carapace-spec compatible JSON AST with fish_extensions.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple


def run_command(cmd: List[str], env: Optional[Dict[str, str]] = None, timeout: int = 5) -> Tuple[int, str, str]:
    """Execute a command safely with timeout and wide COLUMNS to prevent truncation."""
    run_env = os.environ.copy()
    run_env["COLUMNS"] = "300"
    run_env["PAGER"] = "cat"
    if env:
        run_env.update(env)
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=run_env,
            timeout=timeout,
        )
        return proc.returncode, proc.stdout, proc.stderr
    except (subprocess.TimeoutExpired, FileNotFoundError, PermissionError) as e:
        return -1, "", str(e)


def extract_enums(desc: str) -> List[str]:
    """Extract enum choices from help description text."""
    patterns = [
        r"(?:possible values|choices|values|options):\s*\[?([a-zA-Z0-9_\-,\s|]+)\]?",
        r"\((?:choices|values):\s*([a-zA-Z0-9_\-,\s|]+)\)",
        r"\(([a-zA-Z0-9_-]+(?:\|[a-zA-Z0-9_-]+)+)\)",
    ]
    for pat in patterns:
        m = re.search(pat, desc, re.IGNORECASE)
        if m:
            raw = m.group(1)
            delims = [",", "|"]
            for d in delims:
                if d in raw:
                    return [x.strip() for x in raw.split(d) if x.strip()]
            return [x.strip() for x in raw.split() if x.strip()]
    return []


def parse_help_output(help_text: str) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], Dict[str, Any]]:
    """Parse help text into subcommands, flags, and metadata."""
    subcommands: List[Dict[str, Any]] = []
    flags: List[Dict[str, Any]] = []
    metadata: Dict[str, Any] = {}

    lines = help_text.splitlines()
    section = "header"
    usage_line = ""

    # Section headers regex
    subcmd_header_re = re.compile(r"^(?:available\s+)?(?:sub)?commands?:", re.IGNORECASE)
    flags_header_re = re.compile(r"^(?:flags|options|switches):", re.IGNORECASE)
    usage_re = re.compile(r"^usage(?:\s+of\s+([a-zA-Z0-9_-]+))?:\s*(.*)$", re.IGNORECASE)

    # Flag parsing regex
    flag_line_re = re.compile(
        r"^\s+(?:(-[a-zA-Z0-9?]),\s+)?(--[a-zA-Z0-9_-]+)(?:[=\s]+([<\[]?[a-zA-Z0-9_-]+[>\]]?))?(?:\s{2,}|\t+)(.*)$"
    )
    short_only_re = re.compile(r"^\s+(-[a-zA-Z0-9?])(?:\s{2,}|\t+)(.*)$")
    long_only_re = re.compile(r"^\s+(--[a-zA-Z0-9_-]+)(?:[=\s]+([<\[]?[a-zA-Z0-9_-]+[>\]]?))?(?:\s{2,}|\t+)(.*)$")
    subcmd_line_re = re.compile(r"^\s{2,6}([a-z][a-z0-9_-]*)(?:\s{2,}|\t+)(.*)$")

    seen_flags: Set[str] = set()
    short_aliases: Dict[str, str] = {}  # target_long -> short_flag

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue

        # Check for usage
        u_match = usage_re.match(line)
        if u_match:
            cmd_target = u_match.group(1)
            usage_line = u_match.group(2).strip()
            if cmd_target and not usage_line:
                # "Usage of <cmd>:" indicates Go flag section begins immediately
                section = "flags"
            continue

        # Check section headers
        if subcmd_header_re.match(stripped):
            section = "subcommands"
            continue
        elif flags_header_re.match(stripped):
            section = "flags"
            continue
        elif re.match(r"^[A-Z][A-Za-z0-9\s_-]+:$", stripped):
            section = "other"
            continue

        # Parse based on active section
        if section == "subcommands":
            m = subcmd_line_re.match(line)
            if m:
                name = m.group(1).strip()
                desc = m.group(2).strip()
                if name != "help":
                    subcommands.append({"name": name, "description": desc})
        elif section in ("flags", "header"):
            # Check for short alias (e.g. -c   Short alias for --continue)
            m_short = short_only_re.match(line)
            if m_short:
                short_val = m_short.group(1).lstrip("-")
                short_desc = m_short.group(2).strip()
                m_alias = re.match(r"^(?:short\s+alias\s+for\s+|alias\s+for\s+)--([a-zA-Z0-9_-]+)", short_desc, re.I)
                if m_alias:
                    target_long = m_alias.group(1)
                    short_aliases[target_long] = short_val
                    continue
                else:
                    # Standalone short flag
                    short = short_val
                    long_name = ""
                    val_placeholder = ""
                    desc = short_desc
            else:
                m = flag_line_re.match(line)
                if m:
                    short = m.group(1) or ""
                    long_name = m.group(2).lstrip("-")
                    val_placeholder = m.group(3) or ""
                    desc = m.group(4).strip() if m.group(4) else ""
                else:
                    m_long = long_only_re.match(line)
                    if m_long:
                        short = ""
                        long_name = m_long.group(1).lstrip("-")
                        val_placeholder = m_long.group(2) or ""
                        desc = m_long.group(3).strip() if m_long.group(3) else ""
                    else:
                        continue

            key = long_name or short
            if not key or key in seen_flags:
                continue
            seen_flags.add(key)

            choices = extract_enums(desc)
            takes_arg = bool(val_placeholder) or bool(choices)
            # Heuristic for repeatable flags
            repeatable = "(repeatable)" in desc.lower()

            # Argument type detection
            arg_type = "bool"
            if takes_arg:
                if choices:
                    arg_type = "enum"
                elif any(x in desc.lower() for x in ["directory", "folder", "path to dir"]):
                    arg_type = "directory"
                elif any(x in desc.lower() for x in ["file", "schema", "path"]):
                    arg_type = "file"
                else:
                    arg_type = "string"

            flags.append({
                "short": short.lstrip("-") if short else None,
                "long": long_name,
                "description": desc,
                "type": arg_type,
                "choices": choices if choices else None,
                "repeatable": repeatable,
            })

    # Attach short aliases
    for f in flags:
        long_n = f.get("long")
        if long_n in short_aliases and not f.get("short"):
            f["short"] = short_aliases[long_n]

    metadata["usage"] = usage_line
    return subcommands, flags, metadata


class CliCrawler:
    """Universal CLI Tree Crawler with Dual-Channel Discovery."""

    def __init__(self, root_cmd: str, max_depth: int = 5, inspect_binary: bool = True):
        self.root_cmd = root_cmd
        self.max_depth = max_depth
        self.inspect_binary = inspect_binary
        self.binary_path = shutil.which(root_cmd) or root_cmd
        self.visited_paths: Set[str] = set()
        self.binary_strings: Set[str] = set()
        self.discovered_env_vars: List[str] = []

    def run_binary_inspection(self) -> Set[str]:
        """Channel 2: Extract candidate flag tokens and environment variables from binary."""
        if not os.path.isfile(self.binary_path):
            return set()

        candidates: Set[str] = set()
        env_vars: Set[str] = set()

        # Run strings command if available
        ret, stdout, _ = run_command(["strings", "-n", "3", self.binary_path])
        if ret == 0:
            lines = stdout.splitlines()
        else:
            # Fallback: scan binary directly
            try:
                with open(self.binary_path, "rb") as f:
                    data = f.read()
                lines = [s.decode("latin1") for s in re.findall(b"[A-Za-z0-9_/-]{3,}", data)]
            except Exception:
                return set()

        flag_pat = re.compile(r"^--[a-z][a-z0-9-]+$")
        env_pat = re.compile(r"^[A-Z0-9_]{3,}_[A-Z0-9_]+$")

        for s in lines:
            s = s.strip()
            if flag_pat.match(s):
                candidates.add(s.lstrip("-"))
            elif env_pat.match(s) and any(kw in s for kw in ["DIR", "PATH", "HOME", "CACHE", "CONFIG", "TOKEN"]):
                env_vars.add(s)

        self.binary_strings = candidates
        self.discovered_env_vars = sorted(list(env_vars))
        return candidates

    def probe_flag(self, cmd_path: List[str], flag: str) -> bool:
        """Probe if a candidate flag is recognized by the CLI parser."""
        probe_cmd = cmd_path + [f"--{flag}", "-h"]
        ret, out, err = run_command(probe_cmd)
        combined = out + err
        # If the CLI explicitly complains that the flag is undefined, it's not a valid flag
        if any(msg in combined.lower() for msg in [
            f"unknown flag: --{flag}",
            f"flags provided but not defined: -{flag}",
            f"unexpected argument \"--{flag}\"",
            f"no such option: --{flag}",
        ]):
            return False
        # If it returns 0 or showed help without complaining about that flag, it's accepted
        return True

    def crawl_node(self, cmd_path: List[str], depth: int = 0) -> Dict[str, Any]:
        """Recursively crawl a command node."""
        path_str = " ".join(cmd_path)
        if path_str in self.visited_paths or depth > self.max_depth:
            return {}
        self.visited_paths.add(path_str)

        # 1. Fetch --help
        ret, stdout, stderr = run_command(cmd_path + ["--help"])
        help_text = stdout if stdout else stderr
        if not help_text and len(cmd_path) > 1:
            # Try -h
            ret, stdout, stderr = run_command(cmd_path + ["-h"])
            help_text = stdout if stdout else stderr

        subcmds, flags, meta = parse_help_output(help_text)

        # 2. Reconcile with binary strings on root node
        if depth == 0 and self.inspect_binary and self.binary_strings:
            known_flags = {f["long"] for f in flags if f.get("long")}
            for cand in self.binary_strings:
                if cand not in known_flags and len(cand) > 2:
                    # Probe candidate
                    if self.probe_flag(cmd_path, cand):
                        flags.append({
                            "short": None,
                            "long": cand,
                            "description": "Discovered via binary inspection (hidden/internal flag)",
                            "type": "bool",
                            "hidden": True,
                        })

        # 3. Recurse into subcommands
        child_nodes: List[Dict[str, Any]] = []
        for sub in subcmds:
            child_name = sub["name"]
            child_res = self.crawl_node(cmd_path + [child_name], depth + 1)
            if child_res:
                child_res["description"] = sub["description"]
                child_nodes.append(child_res)

        node: Dict[str, Any] = {
            "name": cmd_path[-1],
            "description": meta.get("usage", ""),
            "flags": flags,
            "commands": child_nodes if child_nodes else None,
        }
        if depth == 0 and self.discovered_env_vars:
            node["discovered_env_vars"] = self.discovered_env_vars
        return node

    def build_ast(self) -> Dict[str, Any]:
        """Build canonical JSON AST conforming to carapace-spec."""
        if self.inspect_binary:
            self.run_binary_inspection()

        root_node = self.crawl_node([self.root_cmd])
        return {
            "$schema": "https://carapace.sh/schemas/command.json",
            "name": self.root_cmd,
            "description": root_node.get("description", f"Completions for {self.root_cmd}"),
            "flags": root_node.get("flags", []),
            "commands": root_node.get("commands", []),
            "fish_extensions": {
                "discovered_env_vars": self.discovered_env_vars,
                "binary_path": self.binary_path,
                "visited_nodes": list(self.visited_paths),
            },
        }


def main():
    parser = argparse.ArgumentParser(description="Universal CLI Tree Crawler & Spec Extractor")
    parser.add_argument("cli", help="Target CLI command name or path")
    parser.add_argument("-o", "--output", help="Output file path (default: stdout)")
    parser.add_argument("--max-depth", type=int, default=5, help="Maximum crawl depth (default: 5)")
    parser.add_argument("--no-binary", action="store_true", help="Disable static binary inspection")

    args = parser.parse_args()

    crawler = CliCrawler(args.cli, max_depth=args.max_depth, inspect_binary=not args.no_binary)
    ast = crawler.build_ast()

    formatted = json.dumps(ast, indent=2)
    if args.output:
        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(formatted)
        print(f"Generated spec written to: {args.output}", file=sys.stderr)
    else:
        print(formatted)


if __name__ == "__main__":
    main()
