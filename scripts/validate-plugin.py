#!/usr/bin/env python3
"""Check the shared Claude Code / Codex package without third-party dependencies."""

import json
import os
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parent.parent


def validate():
    errors = []

    def check(condition, message):
        if not condition:
            errors.append(message)

    def read_json(path):
        try:
            return json.loads((ROOT / path).read_text())
        except (OSError, ValueError) as error:
            errors.append(f"{path}: {error}")
            return {}

    claude = read_json(".claude-plugin/plugin.json")
    portable = read_json("plugin.json")
    version = claude.get("version", "")
    check(bool(re.fullmatch(r"\d+\.\d+\.\d+", version)), "Invalid plugin version")
    for key in ("name", "version", "description"):
        check(portable.get(key) == claude.get(key), f"Plugin manifests disagree on {key}")
    check(
        portable.get("$schema") == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
        "plugin.json must declare the Agent Plugins schema",
    )

    marketplaces = [
        read_json(".claude-plugin/marketplace.json"),
        read_json(".agents/plugins/marketplace.json"),
    ]
    check(marketplaces[0].get("name") == marketplaces[1].get("name"),
          "Marketplace names disagree")
    for marketplace in marketplaces:
        entries = [p for p in marketplace.get("plugins", []) if p.get("name") == claude.get("name")]
        check(len(entries) == 1, "Each marketplace must contain exactly one iphone-duo entry")
        for entry in entries:
            source = entry.get("source")
            if isinstance(source, dict):
                check(source.get("source") == "local", "Expected local marketplace source")
                source = source.get("path")
            check(source == "./", "Marketplace entry must resolve to this repository root")
    for entry in marketplaces[1].get("plugins", []):
        check(entry.get("policy", {}).get("installation") == "AVAILABLE",
              "Codex plugin must be available for explicit installation")
        check(entry.get("policy", {}).get("authentication") == "ON_INSTALL",
              "Codex marketplace must declare an authentication policy")
        check(bool(entry.get("category")), "Codex marketplace category is missing")

    skills = sorted((ROOT / "skills").glob("*/SKILL.md"))
    check(bool(skills), "No skills found")
    for path in skills:
        body = path.read_text()
        label = str(path.relative_to(ROOT))
        check(f"skill-version: {version}" in body, f"{label}: version marker disagrees")
        check(f"`{path.parent.name} {version}`" in body, f"{label}: -v answer disagrees")
        # References must survive a skills-only install, which excludes the plugin manifests
        # and Claude's agents/ directory. Resolve from the installed skill, never the user's cwd.
        for doc in [path, *path.parent.glob("references/*.md")]:
            for reference in re.findall(r"`(references/[\w-]+\.md)`", doc.read_text()):
                check((path.parent / reference).is_file(), f"{label}: missing {reference}")

    workflow = ROOT / "skills/iphone-duo/references/audit-workflow.md"
    check(workflow.is_file(), "The portable audit workflow is missing from the iphone-duo skill")
    for path in ("skills/iphone-duo/SKILL.md", "agents/iphone-duo-audit.md"):
        check("references/audit-workflow.md" in (ROOT / path).read_text(),
              f"{path}: must use the shared audit workflow")

    if os.environ.get("GITHUB_REF_TYPE") == "tag":
        check(os.environ.get("GITHUB_REF_NAME") == f"v{version}", "Release tag disagrees with version")
        check(f"## [{version}] — " in (ROOT / "CHANGELOG.md").read_text(), "Release changelog is missing")

    return errors


if __name__ == "__main__":
    failures = validate()
    if failures:
        print("\n".join(f"ERROR: {error}" for error in failures), file=sys.stderr)
        sys.exit(1)
    print("Plugin manifests, marketplaces, skill versions and bundled audit references agree.")
