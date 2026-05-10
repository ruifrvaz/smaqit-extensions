# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "pyyaml>=6.0",
# ]
# ///
"""scan-metadata.py — Batch frontmatter extractor for smaqit.project-recap

Usage:
    uv run scripts/scan-metadata.py <workspace-root>
    uv run scripts/scan-metadata.py --help

Arguments:
    workspace-root   Absolute or relative path to the project root directory.
                     The script searches for:
                       - agents/*.agent.md   (type: "agent")
                       - skills/*/SKILL.md   (type: "skill")

Output (stdout):
    Newline-delimited JSON. Each line is one object with fields:
      type        "skill" | "agent"
      name        Value of frontmatter `name` field
      version     Value of frontmatter `metadata.version` (or `version` if not nested)
      description Value of frontmatter `description` field
      path        File path relative to workspace-root

Diagnostics (stderr):
    [SCAN]    scanning a directory
    [FOUND]   found a candidate file
    [WARN]    unreadable or malformed file (processing continues)
    [ERROR]   fatal error (processing stops)

Exit codes:
    0   Success — at least one component entry written to stdout
    1   No files found matching the expected patterns
    2   Argument error (wrong number of arguments or --help)
"""

import json
import sys
import os
import glob

try:
    import yaml
except ImportError:  # pragma: no cover
    print("[ERROR] pyyaml is required. Run: uv run scripts/scan-metadata.py", file=sys.stderr)
    sys.exit(2)


def usage() -> None:
    print(__doc__, file=sys.stderr)


def extract_frontmatter(path: str) -> dict | None:
    """Return the parsed YAML frontmatter dict from a Markdown file, or None."""
    try:
        with open(path, encoding="utf-8") as fh:
            content = fh.read()
    except OSError as exc:
        print(f"[WARN] Cannot read {path}: {exc}", file=sys.stderr)
        return None

    if not content.startswith("---"):
        return None

    # Find closing ---
    end = content.find("\n---", 3)
    if end == -1:
        print(f"[WARN] No closing --- in frontmatter: {path}", file=sys.stderr)
        return None

    raw = content[3:end].strip()
    try:
        return yaml.safe_load(raw) or {}
    except yaml.YAMLError as exc:
        print(f"[WARN] YAML parse error in {path}: {exc}", file=sys.stderr)
        return None


def resolve_version(fm: dict) -> str:
    """Extract version from frontmatter — handles nested metadata.version."""
    metadata = fm.get("metadata") or {}
    if isinstance(metadata, dict):
        v = metadata.get("version")
        if v:
            return str(v)
    # Flat fallback
    v = fm.get("version")
    return str(v) if v else "unknown"


def scan(root: str) -> list[dict]:
    results: list[dict] = []

    # --- agents/*.agent.md ---
    agents_dir = os.path.join(root, "agents")
    print(f"[SCAN] agents dir: {agents_dir}", file=sys.stderr)
    if os.path.isdir(agents_dir):
        for path in sorted(glob.glob(os.path.join(agents_dir, "*.agent.md"))):
            print(f"[FOUND] {path}", file=sys.stderr)
            fm = extract_frontmatter(path)
            if fm is None:
                continue
            results.append({
                "type": "agent",
                "name": str(fm.get("name", os.path.basename(path))),
                "version": resolve_version(fm),
                "description": str(fm.get("description", "")),
                "path": os.path.relpath(path, root),
            })
    else:
        print(f"[WARN] agents/ directory not found at {agents_dir} — skipping", file=sys.stderr)

    # --- skills/*/SKILL.md ---
    skills_dir = os.path.join(root, "skills")
    print(f"[SCAN] skills dir: {skills_dir}", file=sys.stderr)
    if os.path.isdir(skills_dir):
        for path in sorted(glob.glob(os.path.join(skills_dir, "*/SKILL.md"))):
            print(f"[FOUND] {path}", file=sys.stderr)
            fm = extract_frontmatter(path)
            if fm is None:
                continue
            results.append({
                "type": "skill",
                "name": str(fm.get("name", os.path.basename(os.path.dirname(path)))),
                "version": resolve_version(fm),
                "description": str(fm.get("description", "")),
                "path": os.path.relpath(path, root),
            })
    else:
        print(f"[WARN] skills/ directory not found at {skills_dir} — skipping", file=sys.stderr)

    return results


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] in ("--help", "-h"):
        usage()
        sys.exit(2)

    if len(sys.argv) != 2:
        print("[ERROR] Expected exactly one argument: <workspace-root>", file=sys.stderr)
        print("        Run with --help for usage.", file=sys.stderr)
        sys.exit(2)

    root = sys.argv[1]

    if not os.path.isdir(root):
        print(f"[ERROR] workspace-root is not a directory: {root}", file=sys.stderr)
        sys.exit(2)

    root = os.path.abspath(root)
    entries = scan(root)

    if not entries:
        print("[ERROR] No agent or skill files found under the workspace root.", file=sys.stderr)
        sys.exit(1)

    for entry in entries:
        print(json.dumps(entry))


if __name__ == "__main__":
    main()
