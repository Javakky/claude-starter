#!/usr/bin/env bash
# PR review findings を解析し GitHub API で投稿する共通スクリプト。
# run-claude-review action の Claude/Codex 両パスから呼び出される。
# 全処理を sh + jq で実装。
#
# 必須環境変数:
#   GH_TOKEN, PR_NUMBER, REVIEW_RUN_ID, REVIEW_HEAD_SHA, GITHUB_REPOSITORY
# オプション:
#   REVIEW_CAN_APPROVE (default: false)
set -euo pipefail

if [ ! -f .codex-review-findings.json ]; then
  echo "::error::.codex-review-findings.json not found"
  exit 1
fi

# --- PR 変更ファイル一覧を JSONL で取得 ---
PR_FILES_JSONL=.review-pr-files.jsonl
if ! gh api "repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/files" \
     --paginate --jq '.[]' > "$PR_FILES_JSONL" 2>/dev/null; then
  : > "$PR_FILES_JSONL"
fi

COMMIT_ID=$(git rev-parse HEAD)

# --- Freshness 検証 ---
generated_run_id=$(jq -r '.generated_by_run_id // ""' .codex-review-findings.json)
generated_head_sha=$(jq -r '.generated_for_head_sha // ""' .codex-review-findings.json)
summary=$(jq -r '.summary // ""' .codex-review-findings.json)

if [ -z "$summary" ]; then
  echo "::error::Structured review payload missing non-empty summary"; exit 1
fi
if [ "$generated_run_id" != "$REVIEW_RUN_ID" ]; then
  echo "::error::run mismatch: expected $REVIEW_RUN_ID, got ${generated_run_id:-<empty>}"; exit 1
fi
if [ "$generated_head_sha" != "$REVIEW_HEAD_SHA" ]; then
  echo "::error::head SHA mismatch: expected $REVIEW_HEAD_SHA, got ${generated_head_sha:-<empty>}"; exit 1
fi
if ! jq -e '.findings | type == "array"' .codex-review-findings.json >/dev/null 2>&1; then
  echo "::error::findings must be an array"; exit 1
fi

# --- PR ファイルから変更ファイル一覧と valid right lines を計算 ---
# パッチの差分ヘッダを解析し、コメント可能な行番号を特定する
if [ -s "$PR_FILES_JSONL" ]; then
  if ! jq -s '
    [.[] | select(.filename) | {
      key: .filename,
      value: (
        (.patch // "") | split("\n") | reduce .[] as $line (
          {cur: null, acc: []};
          if ($line | startswith("@@")) then
            (try ($line | capture("\\+(?<s>[0-9]+)") | .s | tonumber) catch null) as $s |
            .cur = $s
          elif .cur == null then .
          elif ($line | startswith("\\")) then .
          elif ($line | startswith("+")) or ($line | startswith(" ")) then
            .acc += [.cur] | .cur += 1
          elif ($line | startswith("-")) then .
          else .cur += 1 end
        ) | .acc
      )
    }] | from_entries
  ' "$PR_FILES_JSONL" > .review-valid-lines.json 2>/dev/null; then
    echo "::warning::PR ファイル一覧のパースに失敗しました"
    echo '{}' > .review-valid-lines.json
  fi
  jq -s '[.[].filename // empty] | unique' "$PR_FILES_JSONL" > .review-changed-files.json 2>/dev/null || echo '[]' > .review-changed-files.json
else
  echo '{}' > .review-valid-lines.json
  echo '[]' > .review-changed-files.json
fi

# --- Findings 処理 ---
# findings を行コメント用 comments と fallback に分類し、verdict を決定する
VALID_LINES_JSON=$(cat .review-valid-lines.json)
CHANGED_FILES_JSON=$(cat .review-changed-files.json)

jq --arg commit_id "$COMMIT_ID" \
   --argjson valid_lines "$VALID_LINES_JSON" \
   --argjson changed_files "$CHANGED_FILES_JSON" \
'
# ユーティリティ定義
def abs: if . < 0 then (- .) else . end;
def sev_rank: {"low": 0, "medium": 1, "high": 2, "critical": 3};
def nearest_threshold: 3;
def trim: sub("^\\s+"; "") | sub("\\s+$"; "");

def render_body:
  ["問題: \(.title // "" | tostring | trim)",
   "根拠: \(.evidence // "" | tostring | trim)",
   "修正案: \(.suggestion // "" | tostring | trim)",
   "影響: \(.impact // "" | tostring | trim)"] | join("\n");

# codex-review-key marker: stale thread 解決に使用する識別子を base64 で埋め込む
def review_marker($path; $line; $title):
  ({path: $path, line: $line, title: ($title | tostring | gsub("\\s+"; " ") | trim)}
  | tojson | @base64)
  | "<!-- codex-review-key:\(.) -->";

# marker を保護しつつ body を truncate する
def protect_body($marker):
  (65000 - ($marker | length) - 1) as $avail |
  if $avail < 0 then error("review marker is longer than the supported comment length") else . end |
  "\(.[:$avail])\n\($marker)";

# 最寄りの有効行を検索
def nearest_valid($path; $line):
  ($valid_lines[$path] // []) |
  if length == 0 then null
  else map({v: ., d: ((. - $line) | abs)}) | sort_by(.d) | .[0].v end;

# is_blocking のパース
def parse_blocking:
  if type == "boolean" then .
  elif . == null then true
  else (tostring | ascii_downcase) as $s |
    if ($s == "true" or $s == "1" or $s == "yes") then true
    elif ($s == "false" or $s == "0" or $s == "no") then false
    else error("is_blocking must be boolean-compatible: \(.)") end
  end;

# tracking_issue のバリデーション
def validate_tracking($blocking):
  (. // "" | tostring | trim) as $v |
  if $blocking then $v
  elif ($v | length) == 0 then error("Non-blocking finding must include tracking_issue")
  elif ($v | test("^#?[0-9]+$")) then $v
  elif ($v | test("^https://github\\.com/[^/]+/[^/]+/issues/[0-9]+$")) then $v
  else error("tracking_issue must be an issue number or GitHub issue URL: \(.)") end;

# --- メイン処理 ---
(.summary // "" | tostring | trim) as $summary |
($changed_files | map({(.): true}) | add // {}) as $changed_set |

reduce ((.findings // [])[] | select(type == "object")) as $raw (
  {comments: [], fallback: [], max_sev: 0, max_bsev: 0, seen: {}};

  # 必須キーの確認
  (["path","line","severity","is_blocking","tracking_issue","title","evidence","suggestion","impact"]
   | map(select($raw | has(.) | not))) as $miss |
  (if ($miss | length) > 0 then error("Finding missing required keys: \($miss | join(", "))") else . end) |

  ($raw.severity // "low" | tostring | ascii_downcase) as $sev |
  (if (sev_rank | has($sev) | not) then error("Invalid finding severity: \($sev)") else . end) |
  ($raw.is_blocking | parse_blocking) as $blocking |
  ($raw.tracking_issue | validate_tracking($blocking)) |
  (sev_rank[$sev]) as $rank |
  .max_sev = ([.max_sev, $rank] | max) |
  (if $blocking then .max_bsev = ([.max_bsev, $rank] | max) else . end) |

  ($raw.path // "" | tostring | trim) as $path |
  (if ($path | length) == 0 then error("Finding path must be non-empty") else . end) |

  # 非空フィールドの検証
  (["title","evidence","suggestion","impact"]
   | map(select(($raw[.] // "" | tostring | trim | length) == 0))) as $empty |
  (if ($empty | length) > 0 then error("Finding field \"\($empty[0])\" must be non-empty") else . end) |

  (try ($raw.line | if type == "number" then . else tonumber end)
   catch error("Finding line must be integer-compatible: \($raw.line)")) as $req |
  ($raw | render_body) as $body |

  if $sev == "low" then .
  elif ($changed_set[$path] | not) then error("Finding path outside PR diff: \($path)")
  elif $req <= 0 then error("Finding line must be positive: \($req)")
  else
    ("\($path):\($req)") as $loc |
    if .seen[$loc] then
      .fallback += ["- [fallback:duplicate] `\($path):\($req)`\n\($body)"]
    else
      .seen[$loc] = true |
      # 指定行が差分の有効行に含まれるかチェック
      (($valid_lines[$path] // []) | length > 0 and (map(select(. == $req)) | length) == 0) as $oob |
      if $oob then
        nearest_valid($path; $req) as $near |
        if $near != null and (($near - $req) | abs) <= nearest_threshold then
          review_marker($path; $req; $raw.title) as $mk |
          ("\($body)\n\n補足: requested_line=\($req), nearest_valid_line=\($near)" | protect_body($mk)) as $full |
          .comments += [{path: $path, line: $near, side: "RIGHT", body: $full}]
        elif $near != null then
          .fallback += ["- [fallback:not_in_diff_out_of_range] `\($path):\($req)`\nrequested_line=\($req), nearest_valid_line=\($near)\n\($body)"]
        else
          .fallback += ["- [fallback:not_in_diff] `\($path):\($req)`\nrequested_line=\($req)\n\($body)"]
        end
      else
        review_marker($path; $req; $raw.title) as $mk |
        ($body | protect_body($mk)) as $full |
        .comments += [{path: $path, line: $req, side: "RIGHT", body: $full}]
      end
    end
  end
) |

# verdict 決定: blocking な high 以上 → REQUEST_CHANGES、medium 以上 → COMMENT、それ以外 → APPROVE
(if .max_bsev >= 2 then "REQUEST_CHANGES" elif .max_sev >= 1 then "COMMENT" else "APPROVE" end) as $evt |

{
  payload: ({event: $evt, body: (if ($summary | length) > 0 then $summary else "AI review findings" end)}
    + if ($commit_id | length) > 0 then {commit_id: $commit_id} else {} end),
  comments: .comments,
  fallback: .fallback,
  event: $evt
}
' .codex-review-findings.json > .review-processed.json

# 出力ファイルへの書き出し
jq '.payload' .review-processed.json > .review-payload.json
jq '.comments' .review-processed.json > .review-comments.json

REVIEW_EVENT=$(jq -r '.event' .review-processed.json)
COMMENTS_COUNT=$(jq '.comments | length' .review-processed.json)
FALLBACK_COUNT=$(jq '.fallback | length' .review-processed.json)

# fallback コメント
if [ "$FALLBACK_COUNT" -gt 0 ]; then
  {
    printf '⚠️ 一部の指摘は行コメントにできなかったため conversation にフォールバックしました。\n\n'
    jq -r '.fallback[]' .review-processed.json
  } > .review-fallback.md
else
  : > .review-fallback.md
fi

# meta 出力
printf 'COMMENTS_COUNT=%s\nFALLBACK_COUNT=%s\nREVIEW_EVENT=%s\n' \
  "$COMMENTS_COUNT" "$FALLBACK_COUNT" "$REVIEW_EVENT" > .review-meta.env

# --- APPROVE フォールバック処理 ---
if [ "$REVIEW_EVENT" = "APPROVE" ] && [ "${REVIEW_CAN_APPROVE:-false}" != "true" ]; then
  echo "::warning::codex_github_token が未設定のため APPROVE を COMMENT にフォールバックします"
  jq --arg note "Note: APPROVE requires codex_github_token, so this result is posted as COMMENT." \
     '.event = "COMMENT" | .body = (if .body == "" then $note else (.body + "\n\n" + $note) end)' \
     .review-payload.json > .review-payload.json.tmp && mv .review-payload.json.tmp .review-payload.json
  REVIEW_EVENT="COMMENT"
fi

# --- Review summary 投稿 ---
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

# --- 行コメント投稿 ---
# プロセス置換を使用してサブシェルでの変数更新問題を回避
COMMENT_COUNT=0
while IFS=$'\t' read -r path line body_b64; do
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
done < <(jq -r '.[] | "\(.path)\t\(.line)\t\(.body | @base64)"' .review-comments.json)

# フォールバックコメントの投稿
if [ -s .review-fallback.md ]; then
  gh pr comment "$PR_NUMBER" --body-file .review-fallback.md >/dev/null || true
fi
