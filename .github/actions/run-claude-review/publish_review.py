#!/usr/bin/env python3
"""PR review findings を行コメント用ペイロードに変換する共通スクリプト。

run-claude-review action の Claude/Codex 両パスから呼び出される。

必須環境変数:
  PR_FILES_JSONL   - PR 変更ファイル一覧の JSONL ファイルパス
  COMMIT_ID        - レビュー対象コミット SHA
  REVIEW_RUN_ID    - ワークフロー実行 ID (freshness 検証用)
  REVIEW_HEAD_SHA  - PR head SHA (freshness 検証用)

入力ファイル:
  .codex-review-findings.json

出力ファイル:
  .review-payload.json    - reviews API 用ペイロード (event + body + commit_id)
  .review-comments.json   - 行コメント配列
  .review-fallback.md     - フォールバックコメント
  .review-meta.env        - COMMENTS_COUNT, FALLBACK_COUNT, REVIEW_EVENT
"""

import base64
import json
import os
import re
import sys
from pathlib import Path


def main():
    findings_path = Path(".codex-review-findings.json")
    output_payload = Path(".review-payload.json")
    comments_payload = Path(".review-comments.json")
    fallback_path = Path(".review-fallback.md")
    meta_path = Path(".review-meta.env")

    required_keys = (
        "path", "line", "severity", "is_blocking", "tracking_issue",
        "title", "evidence", "suggestion", "impact",
    )

    try:
        data = json.loads(findings_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"Structured review parsing failed: {exc}")
    if not isinstance(data, dict):
        raise SystemExit("Structured review payload must be a JSON object")

    summary = str(data.get("summary", "")).strip()
    findings = data.get("findings")
    generated_by_run_id = str(data.get("generated_by_run_id", "")).strip()
    generated_for_head_sha = str(data.get("generated_for_head_sha", "")).strip()
    expected_run_id = os.environ["REVIEW_RUN_ID"]
    expected_head_sha = os.environ["REVIEW_HEAD_SHA"]
    commit_id = os.environ.get("COMMIT_ID", "")

    if not summary:
        raise SystemExit("Structured review payload missing non-empty summary")
    if generated_by_run_id != expected_run_id:
        raise SystemExit(
            f"Structured review payload run mismatch: "
            f"expected {expected_run_id}, got {generated_by_run_id or '<empty>'}"
        )
    if generated_for_head_sha != expected_head_sha:
        raise SystemExit(
            f"Structured review payload head SHA mismatch: "
            f"expected {expected_head_sha}, got {generated_for_head_sha or '<empty>'}"
        )
    if not isinstance(findings, list):
        raise SystemExit("Structured review payload findings must be an array")

    # PR 変更ファイル一覧のパース
    changed = set()
    valid_right_lines = {}
    pr_files_path = os.environ.get("PR_FILES_JSONL", "")
    if pr_files_path:
        try:
            files_data = []
            for raw_line in Path(pr_files_path).read_text(encoding="utf-8").splitlines():
                raw_line = raw_line.strip()
                if not raw_line:
                    continue
                files_data.append(json.loads(raw_line))
            for f in files_data:
                p = f.get("filename")
                if p:
                    changed.add(p)
                patch = f.get("patch")
                if not p or not patch:
                    continue
                right_lines = set()
                current_new = None
                for raw_line in patch.splitlines():
                    if raw_line.startswith("@@"):
                        match = re.match(
                            r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw_line
                        )
                        if not match:
                            current_new = None
                            continue
                        current_new = int(match.group(1))
                        continue
                    if current_new is None:
                        continue
                    if raw_line.startswith("\\"):
                        continue
                    if raw_line.startswith((" ", "+")):
                        right_lines.add(current_new)
                        current_new += 1
                    elif raw_line.startswith("-"):
                        continue
                    else:
                        current_new += 1
                valid_right_lines[p] = right_lines
        except Exception as exc:
            print(
                f"::warning::PR ファイル一覧のパースに失敗しました: {exc}",
                file=sys.stderr,
            )

    severity_rank = {"low": 0, "medium": 1, "high": 2, "critical": 3}
    nearest_line_threshold = 3
    comments = []
    fallback = []
    max_sev = 0
    max_blocking_sev = 0
    seen_locations = set()  # (path, line) 重複チェック

    def parse_blocking(raw_value):
        if isinstance(raw_value, bool):
            return raw_value
        if raw_value is None:
            return True
        normalized = str(raw_value).strip().lower()
        if normalized in ("true", "1", "yes"):
            return True
        if normalized in ("false", "0", "no"):
            return False
        raise SystemExit(
            f"Finding is_blocking must be a boolean-compatible value: {raw_value!r}"
        )

    def validate_tracking_issue(raw_value, is_blocking):
        value = str(raw_value or "").strip()
        if is_blocking:
            return value
        if not value:
            raise SystemExit("Non-blocking finding must include tracking_issue")
        if re.fullmatch(r"#?\d+", value):
            return value
        if re.fullmatch(r"https://github\.com/[^/]+/[^/]+/issues/\d+", value):
            return value
        raise SystemExit(
            f"tracking_issue must be an issue number or GitHub issue URL: {raw_value!r}"
        )

    def render_body(item):
        return "\n".join([
            f"問題: {str(item.get('title', '')).strip()}",
            f"根拠: {str(item.get('evidence', '')).strip()}",
            f"修正案: {str(item.get('suggestion', '')).strip()}",
            f"影響: {str(item.get('impact', '')).strip()}",
        ])

    def review_marker(path, requested_line, title):
        payload = {
            "path": path,
            "line": requested_line,
            "title": " ".join(str(title or "").strip().split()),
        }
        encoded = base64.b64encode(
            json.dumps(
                payload, ensure_ascii=False, separators=(",", ":")
            ).encode("utf-8")
        ).decode("ascii")
        return f"<!-- codex-review-key:{encoded} -->"

    def render_comment_body(body, marker, max_length=65000):
        """marker を必ず保護してから body を truncate する。"""
        available = max_length - len(marker) - 1
        if available < 0:
            raise SystemExit(
                "review marker is longer than the supported comment length"
            )
        return f"{body[:available]}\n{marker}"

    def nearest_valid_line(path, requested_line):
        valid = sorted(valid_right_lines.get(path, set()))
        if not valid:
            return None
        return min(valid, key=lambda candidate: abs(candidate - requested_line))

    for raw in findings:
        if not isinstance(raw, dict):
            raise SystemExit("Each finding must be a JSON object")
        missing = [key for key in required_keys if key not in raw]
        if missing:
            raise SystemExit(f"Finding missing required keys: {', '.join(missing)}")
        sev = str(raw.get("severity", "low")).lower()
        if sev not in severity_rank:
            raise SystemExit(f"Invalid finding severity: {sev}")
        is_blocking = parse_blocking(raw.get("is_blocking"))
        validate_tracking_issue(raw.get("tracking_issue"), is_blocking)
        max_sev = max(max_sev, severity_rank[sev])
        if is_blocking:
            max_blocking_sev = max(max_blocking_sev, severity_rank[sev])
        path = str(raw.get("path", "")).strip()
        if not path:
            raise SystemExit("Finding path must be a non-empty string")
        line_raw = raw.get("line")
        body = render_body(raw)
        for key in ("title", "evidence", "suggestion", "impact"):
            if not str(raw.get(key, "")).strip():
                raise SystemExit(f"Finding field '{key}' must be non-empty")
        try:
            line = int(line_raw)
        except (TypeError, ValueError):
            raise SystemExit(
                f"Finding line must be an integer-compatible value: {line_raw!r}"
            )
        requested_line = line

        if sev == "low":
            continue
        if path not in changed:
            raise SystemExit(f"Finding path is outside PR diff: {path}")
        if line <= 0:
            raise SystemExit(f"Finding line must be positive: {line}")

        # (path, line) 重複チェック
        location_key = (path, line)
        if location_key in seen_locations:
            fallback.append(f"- [fallback:duplicate] `{path}:{line}`\n{body}")
            continue
        seen_locations.add(location_key)

        if (
            path in valid_right_lines
            and valid_right_lines[path]
            and line not in valid_right_lines[path]
        ):
            nearest = nearest_valid_line(path, line)
            if nearest is not None and abs(nearest - line) <= nearest_line_threshold:
                body = "\n".join([
                    body,
                    "",
                    f"補足: requested_line={line}, nearest_valid_line={nearest}",
                ])
                line = nearest
            else:
                reason = "not_in_diff"
                detail = f"requested_line={line}"
                if nearest is not None:
                    reason = "not_in_diff_out_of_range"
                    detail = f"requested_line={line}, nearest_valid_line={nearest}"
                fallback.append(
                    f"- [fallback:{reason}] `{path}:{line}`\n{detail}\n{body}"
                )
                continue

        marker = review_marker(path, requested_line, raw.get("title", ""))
        comments.append({
            "path": path,
            "line": line,
            "side": "RIGHT",
            "body": render_comment_body(body, marker),
        })

    if max_blocking_sev >= severity_rank["high"]:
        review_event = "REQUEST_CHANGES"
    elif max_sev >= severity_rank["medium"]:
        review_event = "COMMENT"
    else:
        review_event = "APPROVE"

    # review payload に commit_id を含める（concurrent push で誤コミットへの適用を防止）
    payload = {
        "event": review_event,
        "body": summary or "AI review findings",
    }
    if commit_id:
        payload["commit_id"] = commit_id

    output_payload.write_text(
        json.dumps(payload, ensure_ascii=False), encoding="utf-8"
    )
    comments_payload.write_text(
        json.dumps(comments, ensure_ascii=False), encoding="utf-8"
    )

    if fallback:
        base = (
            "⚠️ 一部の指摘は行コメントにできなかったため"
            " conversation にフォールバックしました。\n\n"
        )
        fallback_path.write_text(base + "\n".join(fallback), encoding="utf-8")
    else:
        fallback_path.write_text("", encoding="utf-8")

    meta_path.write_text(
        f"COMMENTS_COUNT={len(comments)}\n"
        f"FALLBACK_COUNT={len(fallback)}\n"
        f"REVIEW_EVENT={review_event}\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
