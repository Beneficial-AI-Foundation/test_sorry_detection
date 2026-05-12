#!/usr/bin/env python3
"""Compare two sorry manifests (base vs head) and report newly introduced
sorry-tainted declarations as a GitHub Actions Job Summary and PR comment.

Usage:
    python3 scripts/sorry-diff.py <base-manifest> <head-manifest>

Environment variables (set by CI):
    GITHUB_STEP_SUMMARY  - path to the job summary file
    GITHUB_REPOSITORY    - owner/repo
    GITHUB_TOKEN         - token with pull-requests:write
    PR_NUMBER            - pull request number
    SORRY_FAIL_ON_NEW    - if "true", exit 1 when new sorries are found
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

MARKER = "<!-- sorry-delta-bot -->"
MAX_ROWS = 50


def read_manifest(path: Path) -> set[str]:
    if not path.exists():
        return set()
    return {line for line in path.read_text().splitlines() if line.strip()}


def parse_line(line: str) -> tuple[str, str, str]:
    parts = line.split()
    return (parts[0] if len(parts) > 0 else "",
            parts[1] if len(parts) > 1 else "",
            parts[2] if len(parts) > 2 else "")


def build_body(has_baseline: bool, new_lines: list[str], total: int) -> str:
    lines = [MARKER, "### Sorry Delta", ""]

    if not has_baseline:
        lines.append(
            f"No baseline available for comparison. "
            f"Current sorry-tainted declarations: {total}")
        return "\n".join(lines)

    new_count = len(new_lines)
    if new_count == 0:
        lines.append(
            f"No new sorry-tainted declarations introduced. ({total} total)")
        return "\n".join(lines)

    s = "s" if new_count > 1 else ""
    lines.append(f"**{new_count} new sorry-tainted declaration{s}** ({total} total)")
    lines.append("")
    lines.append("| Module | Declaration | Kind |")
    lines.append("|--------|-------------|------|")

    for entry in new_lines[:MAX_ROWS]:
        mod, decl, kind = parse_line(entry)
        lines.append(f"| {mod} | `{decl}` | {kind} |")

    remaining = new_count - MAX_ROWS
    if remaining > 0:
        lines.append("")
        lines.append(f"... and {remaining} more (see full manifest in job log)")

    return "\n".join(lines)


def gh(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["gh", *args], capture_output=True, text=True)


def upsert_pr_comment(body: str) -> None:
    pr_number = os.environ.get("PR_NUMBER", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    if not pr_number:
        return

    existing_id = None
    result = gh("api", f"repos/{repo}/issues/{pr_number}/comments")
    if result.returncode == 0:
        try:
            for comment in json.loads(result.stdout):
                if MARKER in comment.get("body", ""):
                    existing_id = comment["id"]
                    break
        except (json.JSONDecodeError, KeyError):
            pass

    if existing_id:
        result = gh("api",
                     f"repos/{repo}/issues/{pr_number}/comments/{existing_id}",
                     "-X", "PATCH", "-f", f"body={body}")
        if result.returncode == 0:
            return

    gh("pr", "comment", pr_number, "--body", body)


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: sorry-diff.py <base-manifest> <head-manifest>", file=sys.stderr)
        sys.exit(1)

    base_path = Path(sys.argv[1])
    head_path = Path(sys.argv[2])

    if not head_path.exists():
        print(f"Error: head manifest not found at '{head_path}'", file=sys.stderr)
        sys.exit(1)

    head_lines = read_manifest(head_path)
    total = len(head_lines)

    has_baseline = base_path.exists()
    if has_baseline:
        base_lines = read_manifest(base_path)
        new_lines = sorted(head_lines - base_lines)
    else:
        new_lines = []

    body = build_body(has_baseline, new_lines, total)

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY", "")
    if summary_path:
        with open(summary_path, "a") as f:
            f.write(body + "\n")

    upsert_pr_comment(body)

    print("--- Sorry Delta Summary ---")
    print(f"Total sorry-tainted: {total}")
    if has_baseline:
        print(f"New in this PR: {len(new_lines)}")

    if os.environ.get("SORRY_FAIL_ON_NEW") == "true" and new_lines:
        print(f"::error::{len(new_lines)} new sorry-tainted declaration(s) introduced")
        sys.exit(1)


if __name__ == "__main__":
    main()
