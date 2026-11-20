# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "skills-ref @ git+https://github.com/agentskills/agentskills@83021e2be457a9b6679148719c1f6074f0ad975e#subdirectory=skills-ref",
# ]
# ///
"""Tests for validate_skills.validate_skill. Run: uv run scripts/test_validate_skills.py"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True  # importing the sibling must not leave __pycache__
sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_skills import validate_skill


class ValidateSkillTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)

    def make_skill(self, dirname="demo", frontmatter=None):
        fields = {"name": "demo", "description": "Does a thing. Use when testing."}
        fields.update(frontmatter or {})
        lines = "\n".join(f"{k}: {v}" for k, v in fields.items())
        skill_dir = self.root / dirname
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(f"---\n{lines}\n---\n\nBody\n")
        return skill_dir

    def test_minimal_valid_skill_passes(self):
        self.assertEqual(validate_skill(self.make_skill()), [])

    def test_argument_hint_is_tolerated(self):
        skill_dir = self.make_skill(frontmatter={"argument-hint": "path to check"})
        self.assertEqual(validate_skill(skill_dir), [])

    def test_other_unknown_field_fails_and_is_named(self):
        problems = validate_skill(self.make_skill(frontmatter={"foo": "bar"}))
        self.assertEqual(len(problems), 1)
        self.assertIn("foo", problems[0])

    def test_name_differing_from_directory_fails(self):
        problems = validate_skill(self.make_skill(dirname="other"))
        self.assertEqual(len(problems), 1)
        self.assertIn("demo", problems[0])

    def test_description_over_limit_fails(self):
        problems = validate_skill(self.make_skill(frontmatter={"description": "x" * 1025}))
        self.assertEqual(len(problems), 1)
        self.assertIn("1024", problems[0])

    def test_directory_without_skill_md_fails(self):
        empty = self.root / "empty"
        empty.mkdir()
        self.assertEqual(len(validate_skill(empty)), 1)


if __name__ == "__main__":
    unittest.main()
