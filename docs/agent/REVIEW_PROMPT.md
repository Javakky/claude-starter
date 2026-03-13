この PR の変更内容をレビューしてください。

出力ルール:
1. 主要なレビュー結果を `.codex-review-findings.json` に JSON 形式で保存する
2. サマリーを `.codex-summary.md` に保存する
3. `.codex-review-findings.json` は次の形式に従う
{
  "summary": "全体サマリー",
  "generated_by_run_id": "{{REVIEW_RUN_ID}}",
  "generated_for_head_sha": "{{REVIEW_HEAD_SHA}}",
  "findings": [
    {
      "path": "ファイルパス",
      "line": 123,
      "severity": "low|medium|high|critical",
      "is_blocking": true,
      "tracking_issue": "https://github.com/owner/repo/issues/123 or ''",
      "title": "問題の要約",
      "evidence": "根拠",
      "suggestion": "修正案",
      "impact": "影響範囲"
    }
  ]
}

注記:
- 行コメント対象は medium 以上
- low はサマリーのみで可
- 既知のフォローアップ issue として管理済みの課題は `is_blocking: false` とし、`tracking_issue` に issue URL か issue 番号文字列を入れる
- `is_blocking: true` にするのは、この PR を止めるべき未管理の問題だけ
