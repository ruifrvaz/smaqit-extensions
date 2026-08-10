#!/usr/bin/env python3
"""Generate platform-specific agent, command, and skill files for the installer.

Every artifact type follows the same rule: source lives at the repo root (or in
.smaqit/definitions/ for metadata/content that only makes sense per-platform),
and compiled, platform-resolved output exists ONLY inside installer/ (gitignored,
rebuilt by `make -C installer prepare`). Nothing here is ever written back to
the repo root.

Agents — split across two committed locations:
  agents/<name>.agent.md                             - canonical body (no frontmatter)
  .smaqit/definitions/agents/<name>.frontmatter.yaml  - per-platform metadata
                                                        (frontmatter for Copilot/
                                                        Claude, TOML fields for Codex)
                                                        and any {{PLACEHOLDER}} values
  -> installer/agents-copilot/<name>.agent.md   (GitHub Copilot custom agent)
  -> installer/agents-claude/<name>.md          (Claude Code subagent; dotted filename
                                                  — Claude requires the frontmatter
                                                  `name:` value itself to be hyphenated,
                                                  not the path)
  -> installer/agents-codex/<name>.toml         (Codex project custom agent)

Commands — Claude Code-only (Copilot invokes an agent by its own `name:`
directly, so it needs no separate command file). Copied verbatim:
  commands/<name>.md
  -> installer/commands-claude/<name>.md

Skills — one shared source tree; SKILL.md frontmatter needs no per-platform
variance, so directory/file names stay identical across platforms. Two kinds
of platform-specific content are resolved here, both text substitutions
applied after copying:
  - [SMAQIT_SKILLS_DIR] — each skill's own install path, referenced in a few
    usage comments. Resolved for every skill, no definitions file needed.
  - {{PLACEHOLDER}} tokens — for the handful of skills whose CONTENT (not just
    paths) genuinely differs per platform (e.g. smaqit.project-init writes to
    a different instructions file per platform; smaqit.release-git-pr's push
    step uses direct git outside Copilot). Resolved
    only for skills with a matching .smaqit/definitions/skills/<name>.placeholders.yaml.
  skills/<name>/**
  -> installer/skills/<name>/**         ([SMAQIT_SKILLS_DIR] -> .github/skills; existing embed path, unchanged)
  -> installer/skills-claude/<name>/**  ([SMAQIT_SKILLS_DIR] -> .claude/skills)
  -> installer/skills-codex/<name>/**   ([SMAQIT_SKILLS_DIR] -> .agents/skills)

Run via `make -C installer prepare`, or directly after editing agents/,
commands/, skills/, or .smaqit/definitions/:
  python3 scripts/generate-targets.py
"""
import json
import re
import shutil
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent

PLATFORMS = ("copilot", "claude", "codex")

AGENTS_SRC_DIR = ROOT / "agents"
AGENTS_DEFS_DIR = ROOT / ".smaqit" / "definitions" / "agents"
AGENTS_OUT_DIR_BY_PLATFORM = {
    "copilot": ROOT / "installer" / "agents-copilot",
    "claude": ROOT / "installer" / "agents-claude",
    "codex": ROOT / "installer" / "agents-codex",
}
AGENT_OUT_SUFFIX_BY_PLATFORM = {
    "copilot": ".agent.md",
    "claude": ".md",
    "codex": ".toml",
}

COMMANDS_SRC_DIR = ROOT / "commands"
COMMANDS_OUT_DIR = ROOT / "installer" / "commands-claude"

SKILLS_SRC_DIR = ROOT / "skills"
SKILLS_DEFS_DIR = ROOT / ".smaqit" / "definitions" / "skills"
SKILLS_OUT_DIR_BY_PLATFORM = {
    "copilot": ROOT / "installer" / "skills",
    "claude": ROOT / "installer" / "skills-claude",
    # Codex skills share the same content as Copilot skills; no separate
    # skills-codex/ tree is generated. Both platforms read from the same
    # global ~/.agents/skills/ directory at install time.
}
SKILLS_DIR_BY_PLATFORM = {
    "copilot": "~/.agents/skills",
    "claude": "~/.claude/skills",
    "codex": "~/.agents/skills",
}

AGENT_SUFFIX = ".agent.md"
PLACEHOLDER_RE = re.compile(r"\{\{([A-Z0-9_]+)\}\}")


class FlowList(list):
    """A list that always renders in YAML flow style, e.g. [a, b, c]."""


class QuotedStr(str):
    """A string that always renders with double-quote style, e.g. "0.4.0"."""


def _represent_flow_list(dumper: yaml.Dumper, data: "FlowList"):
    return dumper.represent_sequence("tag:yaml.org,2002:seq", data, flow_style=True)


def _represent_quoted_str(dumper: yaml.Dumper, data: "QuotedStr"):
    return dumper.represent_scalar("tag:yaml.org,2002:str", str(data), style='"')


yaml.SafeDumper.add_representer(FlowList, _represent_flow_list)
yaml.SafeDumper.add_representer(QuotedStr, _represent_quoted_str)


def dump_frontmatter(data: dict) -> str:
    data = dict(data)
    if isinstance(data.get("tools"), list):
        data["tools"] = FlowList(data["tools"])
    if isinstance(data.get("metadata"), dict) and "version" in data["metadata"]:
        data["metadata"] = dict(data["metadata"])
        data["metadata"]["version"] = QuotedStr(data["metadata"]["version"])
    return yaml.safe_dump(
        data, sort_keys=False, default_flow_style=False, width=1000, allow_unicode=True
    ).strip()


def resolve_placeholders(text: str, values: dict, source_name: str, platform: str) -> str:
    """Substitute {{TOKEN}} occurrences in text using this platform's values."""

    def replace(match: re.Match) -> str:
        key = match.group(1)
        if key not in values:
            raise ValueError(
                f"{source_name}: placeholder {{{{{key}}}}} used but not defined "
                f"for platform '{platform}'"
            )
        return values[key]

    return PLACEHOLDER_RE.sub(replace, text)


def render_codex_agent(metadata: dict, body: str, source_name: str) -> str:
    """Render a Codex project custom agent as standalone TOML."""
    required = ("name", "description")
    missing = [key for key in required if not metadata.get(key)]
    if missing:
        raise ValueError(f"{source_name}: Codex metadata missing: {', '.join(missing)}")
    if "'''" in body:
        raise ValueError(
            f"{source_name}: agent body contains triple single quotes and cannot be "
            "rendered as a TOML literal string"
        )

    return (
        f"name = {json.dumps(metadata['name'], ensure_ascii=False)}\n"
        f"description = {json.dumps(metadata['description'], ensure_ascii=False)}\n"
        "developer_instructions = '''\n\n"
        f"{body.rstrip()}\n"
        "'''\n"
    )


def generate_agents() -> None:
    if not AGENTS_SRC_DIR.exists():
        print(f"no source directory at {AGENTS_SRC_DIR}", file=sys.stderr)
        sys.exit(1)

    sources = sorted(AGENTS_SRC_DIR.glob(f"*{AGENT_SUFFIX}"))
    if not sources:
        print(f"no *{AGENT_SUFFIX} sources found in {AGENTS_SRC_DIR}", file=sys.stderr)
        sys.exit(1)

    missing = [
        src.name[: -len(AGENT_SUFFIX)]
        for src in sources
        if not (AGENTS_DEFS_DIR / f"{src.name[:-len(AGENT_SUFFIX)]}.frontmatter.yaml").exists()
    ]
    if missing:
        print(
            f"missing .smaqit/definitions/agents/*.frontmatter.yaml for: {', '.join(missing)}",
            file=sys.stderr,
        )
        sys.exit(1)

    for out_dir in AGENTS_OUT_DIR_BY_PLATFORM.values():
        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)

    for src in sources:
        stem = src.name[: -len(AGENT_SUFFIX)]  # e.g. "smaqit.release.local"
        body = src.read_text()
        manifest = yaml.safe_load((AGENTS_DEFS_DIR / f"{stem}.frontmatter.yaml").read_text())
        placeholders = manifest.get("placeholders", {})

        for platform in PLATFORMS:
            if platform not in manifest:
                continue
            metadata = manifest[platform]
            values = {key: platform_values[platform] for key, platform_values in placeholders.items()}
            resolved_body = resolve_placeholders(body, values, stem, platform)

            out_suffix = AGENT_OUT_SUFFIX_BY_PLATFORM[platform]
            out_path = AGENTS_OUT_DIR_BY_PLATFORM[platform] / f"{stem}{out_suffix}"
            if platform == "codex":
                content = render_codex_agent(metadata, resolved_body, stem)
            else:
                content = "---\n" f"{dump_frontmatter(metadata)}\n" "---\n\n" f"{resolved_body}"
            out_path.write_text(content)
            print(f"wrote {out_path.relative_to(ROOT)}")


def copy_commands() -> None:
    if not COMMANDS_SRC_DIR.exists():
        return
    COMMANDS_OUT_DIR.mkdir(parents=True, exist_ok=True)
    for src in sorted(COMMANDS_SRC_DIR.glob("*.md")):
        out_path = COMMANDS_OUT_DIR / src.name
        out_path.write_text(src.read_text())
        print(f"wrote {out_path.relative_to(ROOT)}")


def generate_skills() -> None:
    if not SKILLS_SRC_DIR.exists():
        print(f"no source directory at {SKILLS_SRC_DIR}", file=sys.stderr)
        sys.exit(1)

    for platform, out_dir in SKILLS_OUT_DIR_BY_PLATFORM.items():
        if out_dir.exists():
            shutil.rmtree(out_dir)
        shutil.copytree(SKILLS_SRC_DIR, out_dir)

        skills_dir = SKILLS_DIR_BY_PLATFORM[platform]
        for path in out_dir.rglob("*"):
            if not path.is_file():
                continue
            try:
                text = path.read_text()
            except UnicodeDecodeError:
                continue  # binary asset, nothing to substitute

            if "[SMAQIT_SKILLS_DIR]" in text:
                text = text.replace("[SMAQIT_SKILLS_DIR]", skills_dir)

            skill_name = path.relative_to(out_dir).parts[0]
            defs_path = SKILLS_DEFS_DIR / f"{skill_name}.placeholders.yaml"
            if defs_path.exists():
                manifest = yaml.safe_load(defs_path.read_text())
                values = {key: platform_values[platform] for key, platform_values in manifest.items()}
                text = resolve_placeholders(text, values, skill_name, platform)

            path.write_text(text)

        file_count = sum(1 for p in out_dir.rglob("*") if p.is_file())
        print(f"wrote {out_dir.relative_to(ROOT)}/ ({file_count} files)")


def main() -> None:
    generate_agents()
    copy_commands()
    generate_skills()


if __name__ == "__main__":
    main()
