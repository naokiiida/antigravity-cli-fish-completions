#!/usr/bin/env python3
"""
Unit tests for completions-kit: crawler, compiler, and isolation invariants.
"""

import json
import subprocess
import tempfile
import unittest
from pathlib import Path

import importlib.util

# Add generator scripts to path
KIT_ROOT = Path(__file__).resolve().parent.parent
crawl_cli_path = KIT_ROOT / "generate-fish-completions" / "scripts" / "crawl-cli.py"
generate_fish_path = KIT_ROOT / "generate-fish-completions" / "scripts" / "generate-fish.py"

spec_crawl = importlib.util.spec_from_file_location("crawl_cli", crawl_cli_path)
crawl_cli = importlib.util.module_from_spec(spec_crawl)
spec_crawl.loader.exec_module(crawl_cli)

spec_gen = importlib.util.spec_from_file_location("generate_fish", generate_fish_path)
generate_fish = importlib.util.module_from_spec(spec_gen)
spec_gen.loader.exec_module(generate_fish)

extract_enums = crawl_cli.extract_enums
parse_help_output = crawl_cli.parse_help_output
FishGenerator = generate_fish.FishGenerator


class TestCrawler(unittest.TestCase):
    def test_extract_enums(self):
        desc1 = "Set mode (low|medium|high|max)"
        self.assertEqual(extract_enums(desc1), ["low", "medium", "high", "max"])

        desc2 = "Choices: [accept-edits, auto, plan]"
        self.assertEqual(extract_enums(desc2), ["accept-edits", "auto", "plan"])

    def test_parse_help_output_go_format(self):
        help_text = """Usage of myapp:
  -c  Short alias for --continue
  --continue  Continue recent session
  --effort string  Reasoning effort (low|medium|high) (default "medium")
  --add-dir path  Add directory (repeatable)

Available subcommands:
  serve  Start server
  stop   Stop server
"""
        subcmds, flags, meta = parse_help_output(help_text)
        self.assertEqual(len(subcmds), 2)
        self.assertEqual(subcmds[0]["name"], "serve")
        self.assertEqual(subcmds[1]["name"], "stop")

        flag_map = {f["long"]: f for f in flags}
        self.assertIn("continue", flag_map)
        self.assertEqual(flag_map["continue"]["short"], "c")
        self.assertIn("effort", flag_map)
        self.assertEqual(flag_map["effort"]["choices"], ["low", "medium", "high"])
        self.assertTrue(flag_map["add-dir"]["repeatable"])


class TestGenerator(unittest.TestCase):
    def setUp(self):
        self.sample_spec = {
            "name": "sample",
            "flags": [
                {"long": "continue", "short": "c", "type": "bool", "description": "Continue session"},
                {"long": "effort", "short": None, "type": "enum", "choices": ["low", "high"], "description": "Effort level"},
            ],
            "commands": [
                {
                    "name": "remote",
                    "description": "Remote control",
                    "commands": [
                        {
                            "name": "start",
                            "description": "Start daemon",
                            "flags": [
                                {"long": "name", "type": "string", "description": "Instance name"},
                            ]
                        }
                    ]
                }
            ]
        }

    def test_root_flag_isolation(self):
        gen = FishGenerator(self.sample_spec)
        code = gen.generate_script()

        # Invariant: Root flags MUST have __fish_use_subcommand
        self.assertIn('complete -c sample -n "__fish_use_subcommand" -s c -l continue', code)
        self.assertIn('complete -c sample -n "__fish_use_subcommand" -l effort', code)

        # Invariant: Subcommand flags MUST NOT have __fish_use_subcommand
        self.assertNotIn('complete -c sample -n "__fish_use_subcommand" -l name', code)
        self.assertIn('__fish_seen_subcommand_from remote; and __fish_seen_subcommand_from start', code)

    def test_fish_syntax_validity(self):
        gen = FishGenerator(self.sample_spec)
        code = gen.generate_script()
        with tempfile.NamedTemporaryFile("w", suffix=".fish", delete=False) as f:
            f.write(code)
            tmp_path = f.name

        try:
            ret = subprocess.run(["fish", "-n", tmp_path], capture_output=True, text=True)
            self.assertEqual(ret.returncode, 0, f"Fish syntax error: {ret.stderr}")
        finally:
            Path(tmp_path).unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
