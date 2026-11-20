# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "skills-ref @ git+https://github.com/agentskills/agentskills@83021e2be457a9b6679148719c1f6074f0ad975e#subdirectory=skills-ref",
# ]
# ///
"""Validate Agent Skills against the agentskills.io spec using skills-ref.

Usage: uv run scripts/validate_skills.py [skill-dir ...]
"""

import sys
from pathlib import Path

from skills_ref.errors import ParseError
from skills_ref.parser import find_skill_md, parse_frontmatter
from skills_ref.validator import validate_metadata

# Claude Code frontmatter fields the agentskills.io spec does not know.
CLAUDE_CODE_FIELDS = {"argument-hint"}

REPO_ROOT = Path(__file__).resolve().parent.parent


def validate_skill(skill_dir: Path) -> list[str]:
    """Return the problems found in one skill directory (empty if valid)."""
    if not skill_dir.exists():
        return [f"Path does not exist: {skill_dir}"]
    if not skill_dir.is_dir():
        return [f"Not a directory: {skill_dir}"]
    skill_md = find_skill_md(skill_dir)
    if skill_md is None:
        return ["Missing required file: SKILL.md"]
    try:
        metadata, _body = parse_frontmatter(skill_md.read_text())
    except ParseError as e:
        return [str(e)]
    for field in CLAUDE_CODE_FIELDS:
        metadata.pop(field, None)
    return validate_metadata(metadata, skill_dir)


def main() -> int:
    if len(sys.argv) > 1:
        skill_dirs = [Path(arg) for arg in sys.argv[1:]]
    else:
        skill_dirs = [p for p in REPO_ROOT.iterdir() if (p / "SKILL.md").is_file()]
    if not skill_dirs:
        print("no skills found")
        return 1

    failed = False
    for skill_dir in sorted(skill_dirs, key=lambda p: p.resolve().name):
        problems = validate_skill(skill_dir)
        name = skill_dir.resolve().name
        if problems:
            failed = True
            print(f"FAIL  {name}")
            for problem in problems:
                print(f"  {problem}")
        else:
            print(f"ok    {name}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
