#!/usr/bin/env bash
# PR review findings を GitHub API で投稿する共通スクリプト。
# run-claude-review action の Claude/Codex 両パスから呼び出される。
#
# 必須環境変数:
#   GH_TOKEN, PR_NUMBER, REVIEW_RUN_ID, REVIEW_HEAD_SHA, GITHUB_REPOSITORY
# オプション:
#   REVIEW_CAN_APPROVE (default: false)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f .codex-review-findings.json ]; then
  echo "::error::.codex-review-findings.json not found"
  exit 1
fi

# PR 変更ファイル一覧を JSONL で取得
PR_FILES_JSONL=.review-pr-files.jsonl
if ! gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/files" \
     --paginate --jq '.[]' > "$PR_FILES_JSONL" 2>/dev/null; then
  : > "$PR_FILES_JSONL"
fi
export PR_FILES_JSONL

COMMIT_ID=$(git rev-parse HEAD)
export COMMIT_ID
export REVIEW_RUN_ID REVIEW_HEAD_SHA

# Python で findings を解析してペイロードを生成
python3 "$SCRIPT_DIR/publish_review.py"

# .review-meta.env の読み取り（source ではなく grep/cut で安全に個別読み取り）
COMMENTS_COUNT=$(grep '^COMMENTS_COUNT=' .review-meta.env | cut -d= -f2)
FALLBACK_COUNT=$(grep '^FALLBACK_COUNT=' .review-meta.env | cut -d= -f2)
REVIEW_EVENT=$(grep '^REVIEW_EVENT=' .review-meta.env | cut -d= -f2)

# APPROVE のフォールバック処理（Python を使わず jq で JSON 操作）
if [ "$REVIEW_EVENT" = "APPROVE" ] && [ "${REVIEW_CAN_APPROVE:-false}" != "true" ]; then
  echo "::warning::codex_github_token が未設定のため APPROVE を COMMENT にフォールバックします"
  jq --arg note "Note: APPROVE requires codex_github_token, so this result is posted as COMMENT." \
     '.event = "COMMENT" | .body = (if .body == "" then $note else (.body + "\n\n" + $note) end)' \
     .review-payload.json > .review-payload.json.tmp && mv .review-payload.json.tmp .review-payload.json
  REVIEW_EVENT="COMMENT"
fi

# Review summary の投稿
if ! gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews" \
     -X POST --input .review-payload.json >/dev/null 2>.review-post.err; then
  ERR_MSG=$(tr '\n' ' ' < .review-post.err | sed 's/[[:space:]]\+/ /g')
  if [ "$REVIEW_EVENT" = "APPROVE" ] && printf '%s' "$ERR_MSG" | grep -q "Unprocessable Entity"; then
    echo "::warning::APPROVE review が拒否されたため COMMENT にフォールバックします"
    jq --arg note "Note: APPROVE could not be submitted, so this result is posted as COMMENT." \
       '.event = "COMMENT" | .body = (if .body == "" then $note else (.body + "\n\n" + $note) end)' \
       .review-payload.json > .review-payload.json.tmp && mv .review-payload.json.tmp .review-payload.json
    if gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews" \
         -X POST --input .review-payload.json >/dev/null 2>.review-post.err; then
      REVIEW_EVENT="COMMENT"
      : > .review-post.err
    else
      ERR_MSG=$(tr '\n' ' ' < .review-post.err | sed 's/[[:space:]]\+/ /g')
    fi
  fi
fi

# API エラー時のフォールバック
if [ -f .review-post.err ] && [ -s .review-post.err ]; then
  ERR_MSG=$(tr '\n' ' ' < .review-post.err | sed 's/[[:space:]]\+/ /g')
  {
    echo "⚠️ review API 投稿に失敗したため conversation にフォールバックしました。"
    echo
    echo "reason: api_error"
    echo "detail: ${ERR_MSG}"
    echo
    cat .review-fallback.md 2>/dev/null || true
  } > .review-fallback-all.md
  gh pr comment "$PR_NUMBER" --body-file .review-fallback-all.md >/dev/null || true
  exit 0
fi

# 行コメントの投稿（jq で NDJSON 変換、rate limit 対策で sleep を挟む）
COMMENT_COUNT=0
jq -r '.[] | "\(.path)\t\(.line)\t\(.body | @base64)"' .review-comments.json \
  | while IFS=$'\t' read -r path line body_b64; do
  [ -z "$path" ] && continue
  body=$(printf '%s' "$body_b64" | base64 -d)
  if ! gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/comments" \
    -X POST \
    -f body="$body" \
    -f commit_id="$COMMIT_ID" \
    -f path="$path" \
    -F line="$line" \
    -f side="RIGHT" >/dev/null 2>.review-comment.err; then
    ERR_MSG=$(tr '\n' ' ' < .review-comment.err | sed 's/[[:space:]]\+/ /g')
    printf '%s\n%s\n\n' "- [fallback:api_error] \`$path:$line\`" "$ERR_MSG" >> .review-fallback.md
  fi
  COMMENT_COUNT=$((COMMENT_COUNT + 1))
  # rate limit 対策: 連続投稿の間に 1 秒待機
  sleep 1
done

# フォールバックコメントの投稿
if [ -s .review-fallback.md ]; then
  gh pr comment "$PR_NUMBER" --body-file .review-fallback.md >/dev/null || true
fi
