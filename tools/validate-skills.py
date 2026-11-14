#!/usr/bin/env python3
"""Validate the skills in this repository.

Checks the invariants an agent runtime needs but that fail silently when broken:
the frontmatter parses, the skill name matches its directory, the description
survives the catalog cap, every path cited by the body exists, and invocation
flags use values the runtime accepts.

Usage: python3 tools/validate-skills.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
SKILLS_DIR = ROOT / "skills"

# Default cap of @deepseek-ai/dsh-tool-skill's catalogDescriptionMaxLength. Longer
# descriptions are truncated in the model-facing catalog, so the trigger sentence
# at the end of a description is the part that silently disappears.
CATALOG_DESCRIPTION_LIMIT = 500

KEBAB = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
CITED_PATH = re.compile(r"\b((?:references|scripts|assets)/[A-Za-z0-9._/-]+)")

INVOCATION_KEYS = ("disable-model-invocation", "user-invocable")
CAMEL_CASE_TRAPS = ("disableModelInvocation", "userInvocable")
TRUE_WORDS = {"true", "yes", "on", "1"}
FALSE_WORDS = {"false", "no", "off", "0"}


def split_frontmatter(text: str) -> tuple[str | None, str]:
    """Return the raw frontmatter block and the body, or (None, text)."""
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end == -1:
        return None, text
    return text[4:end], text[end + 5 :]


def check_skill(skill_dir: Path) -> list[str]:
    errors: list[str] = []
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return ["missing SKILL.md"]

    raw, body = split_frontmatter(skill_md.read_text(encoding="utf-8"))
    if raw is None:
        return ["SKILL.md does not start with a closed '---' frontmatter block"]

    try:
        meta = yaml.safe_load(raw)
    except yaml.YAMLError as exc:
        return [f"frontmatter is not valid YAML: {exc}"]
    if not isinstance(meta, dict):
        return ["frontmatter is not a mapping"]

    name = meta.get("name")
    if not isinstance(name, str) or not name:
        errors.append("frontmatter is missing a string 'name'")
    else:
        if not KEBAB.match(name):
            errors.append(f"name '{name}' is not kebab-case")
        if name != skill_dir.name:
            errors.append(f"name '{name}' does not match directory '{skill_dir.name}'")

    description = meta.get("description")
    if not isinstance(description, str) or not description.strip():
        errors.append("frontmatter is missing a string 'description'")
    else:
        flat = " ".join(description.split())
        if len(flat) > CATALOG_DESCRIPTION_LIMIT:
            errors.append(
                f"description is {len(flat)} chars, over the {CATALOG_DESCRIPTION_LIMIT}-char "
                "catalog cap (the tail with the trigger phrases is what gets truncated)"
            )

    for key in CAMEL_CASE_TRAPS:
        if key in meta:
            errors.append(
                f"'{key}' is camelCase; the runtime only reads "
                f"'{INVOCATION_KEYS[0] if key.startswith('disable') else INVOCATION_KEYS[1]}'"
            )
    for key in INVOCATION_KEYS:
        if key not in meta:
            continue
        value = meta[key]
        if isinstance(value, bool):
            continue
        if isinstance(value, str) and value.strip().lower() in TRUE_WORDS | FALSE_WORDS:
            continue
        errors.append(f"'{key}' must be a boolean or a true/false word, got {value!r}")

    for cited in sorted(set(CITED_PATH.findall(body))):
        if not (skill_dir / cited).exists():
            errors.append(f"body cites '{cited}', which does not exist")

    nested = [p for p in skill_dir.rglob("SKILL.md") if p.parent != skill_dir]
    for path in nested:
        errors.append(f"nested skill at {path.relative_to(skill_dir)} is not discovered")

    return errors


def main() -> int:
    if not SKILLS_DIR.is_dir():
        print(f"error: {SKILLS_DIR} does not exist")
        return 1

    skill_dirs = sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir())
    if not skill_dirs:
        print(f"error: no skill directories under {SKILLS_DIR}")
        return 1

    failed = 0
    for skill_dir in skill_dirs:
        errors = check_skill(skill_dir)
        if errors:
            failed += 1
            print(f"FAIL {skill_dir.name}")
            for error in errors:
                print(f"     - {error}")
        else:
            print(f"ok   {skill_dir.name}")

    total = len(skill_dirs)
    print(f"\n{total - failed}/{total} skills valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
