# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "skills-ref @ git+https://github.com/agentskills/agentskills@83021e2be457a9b6679148719c1f6074f0ad975e#subdirectory=skills-ref",
# ]
# ///
"""Tests for validate_skills.validate_skill. Run: uv run scripts/test_validate_skills.py"""

import contextlib
import io
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True  # importing the sibling must not leave __pycache__
sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_skills import main, validate_skill


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

    def test_path_ending_in_dotdot_is_resolved(self):
        skill_dir = self.make_skill()
        (skill_dir / "sub").mkdir()
        self.assertEqual(validate_skill(skill_dir / "sub" / ".."), [])

    def test_relative_dot_from_inside_the_skill_passes(self):
        skill_dir = self.make_skill()
        cwd = os.getcwd()
        self.addCleanup(os.chdir, cwd)
        os.chdir(skill_dir)
        self.assertEqual(validate_skill(Path(".")), [])

    def test_directory_without_skill_md_fails(self):
        empty = self.root / "empty"
        empty.mkdir()
        problems = validate_skill(empty)
        self.assertEqual(len(problems), 1)
        self.assertIn("SKILL.md", problems[0])

    def test_missing_path_fails(self):
        self.assertEqual(len(validate_skill(self.root / "nope")), 1)

    def test_malformed_frontmatter_reports_one_problem(self):
        for body in ("---\nname: demo\ndescription: x\n", "---\nname: [unclosed\n---\n"):
            with self.subTest(body=body):
                skill_dir = self.root / "demo"
                skill_dir.mkdir()
                (skill_dir / "SKILL.md").write_text(body)
                self.assertEqual(len(validate_skill(skill_dir)), 1)
                shutil.rmtree(skill_dir)

    def test_quoted_bracket_argument_hint_is_tolerated(self):
        skill_dir = self.make_skill(frontmatter={"argument-hint": '"[path]"'})
        self.assertEqual(validate_skill(skill_dir), [])

    def test_argument_hint_does_not_mask_a_real_problem(self):
        skill_dir = self.make_skill(
            frontmatter={"argument-hint": "path", "description": "x" * 1025}
        )
        problems = validate_skill(skill_dir)
        self.assertEqual(len(problems), 1)
        self.assertIn("1024", problems[0])
        self.assertNotIn("argument-hint", problems[0])


class MainTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)

    def make_skill(self, dirname, name=None):
        skill_dir = self.root / dirname
        skill_dir.mkdir()
        (skill_dir / "SKILL.md").write_text(
            f"---\nname: {name or dirname}\ndescription: Does a thing. Use when testing.\n---\n\nBody\n"
        )
        return skill_dir

    def run_main(self, *args, root=None):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = main(list(args), root=root or self.root)
        return code, out.getvalue()

    def test_valid_and_invalid_paths_report_both_and_exit_1(self):
        bad = self.make_skill("aaa", name="mismatch")  # sorts before "zzz"
        good = self.make_skill("zzz")
        code, out = self.run_main(str(good), str(bad))
        self.assertEqual(code, 1)
        self.assertIn("ok    zzz", out)
        self.assertIn("FAIL  aaa", out)
        self.assertLess(out.index("FAIL  aaa"), out.index("ok    zzz"))

    def test_only_valid_paths_exit_0(self):
        code, out = self.run_main(str(self.make_skill("one")), str(self.make_skill("two")))
        self.assertEqual(code, 0)
        self.assertEqual(out, "ok    one\nok    two\n")

    def test_no_arguments_discovers_only_skill_directories_under_root(self):
        self.make_skill("real")
        (self.root / "no-skill").mkdir()
        (self.root / "README.md").write_text("hi\n")
        code, out = self.run_main()
        self.assertEqual(code, 0)
        self.assertEqual(out, "ok    real\n")

    def test_no_arguments_in_empty_root_reports_none_and_exit_1(self):
        code, out = self.run_main()
        self.assertEqual(code, 1)
        self.assertEqual(out, "no skills found\n")


if __name__ == "__main__":
    unittest.main()
