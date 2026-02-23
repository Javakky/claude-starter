#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SRC_TASK = ROOT / "docs/agent/TASK.md"
SRC_PR   = ROOT / "docs/agent/PR.md"

DST_PR   = ROOT / ".github/pull_request_template.md"
DST_ISSUE_DIR = ROOT / ".github/ISSUE_TEMPLATE"
DST_ISSUE = DST_ISSUE_DIR / "agent_task.md"

AUTO_HEADER = """<!--
AUTO-GENERATED.
編集するなら docs/agent/{src} を変更して scripts/sync_templates.py を実行してください。
-->
"""

ISSUE_FRONTMATTER = """---
name: "Agent Task / 作業依頼"
about: "Claude Code / Agent に依頼する作業テンプレ"
title: "[Agent] "
labels: ["agent"]
---

"""

def main():
    if not SRC_TASK.exists():
        raise FileNotFoundError(SRC_TASK)
    if not SRC_PR.exists():
        raise FileNotFoundError(SRC_PR)

    DST_ISSUE_DIR.mkdir(parents=True, exist_ok=True)
    (ROOT / ".github").mkdir(parents=True, exist_ok=True)

    # PR template
    pr_body = SRC_PR.read_text(encoding="utf-8").strip() + "\n"
    DST_PR.write_text(AUTO_HEADER.format(src="PR.md") + "\n" + pr_body, encoding="utf-8")

    # Issue template (Markdown)
    task_body = SRC_TASK.read_text(encoding="utf-8").strip() + "\n"
    DST_ISSUE.write_text(
        ISSUE_FRONTMATTER + "\n" + AUTO_HEADER.format(src="TASK.md") + "\n" + task_body,
        encoding="utf-8",
        )

    print("synced:")
    print(f"- {SRC_PR.relative_to(ROOT)} -> {DST_PR.relative_to(ROOT)}")
    print(f"- {SRC_TASK.relative_to(ROOT)} -> {DST_ISSUE.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
