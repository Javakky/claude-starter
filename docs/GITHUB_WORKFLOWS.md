# GitHub Workflows 設定ガイド

このドキュメントでは、Claude Starter で使用する GitHub Actions ワークフローファイルの設定方法を説明します。

> **Note**: これらのファイルは `.github/workflows/` ディレクトリに手動で配置する必要があります。

---

## 必要なファイル一覧

| ファイルパス | 説明 | 必須 |
|-------------|------|------|
| `.github/workflows/claude.yml` | Claude Code による Issue/PR コメント応答 | 推奨 |
| `.github/workflows/claude_review.yml` | PR 自動レビュー | 推奨 |
| `.github/workflows/lint-scripts.yml` | シェルスクリプトの構文チェック | 推奨 |
| `.github/workflows/sync_templates.yml` | テンプレート同期 | オプション |
| `.github/workflows/reusable-claude.yml` | 再利用可能ワークフロー（提供側） | オプション |
| `.github/workflows/reusable-claude-review.yml` | 再利用可能レビューワークフロー（提供側） | オプション |

---

## 1. シェルスクリプト構文チェック（lint-scripts.yml）

スクリプトの構文エラーを CI で検出するためのワークフローです。

### `.github/workflows/lint-scripts.yml`

```yaml
name: Lint Shell Scripts

on:
  push:
    paths:
      - 'scripts/**/*.sh'
  pull_request:
    paths:
      - 'scripts/**/*.sh'

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Validate shell script syntax
        run: |
          echo "Validating shell script syntax..."
          for script in scripts/*.sh; do
            if [[ -f "$script" ]]; then
              echo "Checking: $script"
              bash -n "$script"
            fi
          done
          echo "All scripts are syntactically valid."

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: './scripts'
          severity: warning
```

### 説明

- `bash -n`: スクリプトの構文チェック（実行せずに検証）
- ShellCheck: より詳細な静的解析（ベストプラクティスのチェック）

---

## 2. Claude Code ワークフロー（claude.yml）

Issue や PR のコメントで `@claude` メンションに応答するワークフローです。

### `.github/workflows/claude.yml`

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

permissions:
  contents: write
  pull-requests: write
  issues: write
  id-token: write

concurrency:
  group: claude-${{ github.repository }}-${{ github.event.issue.number || github.event.pull_request.number }}
  cancel-in-progress: false

jobs:
  claude:
    timeout-minutes: 30
    runs-on: ubuntu-latest
    if: contains(github.event.comment.body, '@claude')

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Resolve Claude options
        id: opts
        uses: actions/github-script@v7
        with:
          script: |
            const body = context.payload.comment?.body ?? "";

            // モデル解析
            const model =
              body.includes("[sonnet]")  ? "sonnet" :
              body.includes("[opus]")  ? "opus" :
              body.includes("[haiku]") ? "haiku" : "sonnet";

            // ターン数解析
            const m = body.match(/\[(?:turns|max-turns)=(\d+)\]/);
            const maxTurns = m ? Number(m[1]) : 100;

            core.setOutput("model", model);
            core.setOutput("max_turns", String(maxTurns));

      - name: Run Claude Code Action
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          claude_args: >-
            --model ${{ steps.opts.outputs.model }}
            --max-turns ${{ steps.opts.outputs.max_turns }}
```

### カスタマイズ

プロジェクト固有のツールを許可する場合は、`claude_args` に `--allowedTools` を追加：

```yaml
claude_args: >-
  --model ${{ steps.opts.outputs.model }}
  --max-turns ${{ steps.opts.outputs.max_turns }}
  --allowedTools "Bash(npm run lint:*)" "Bash(npm run test:*)"
```

---

## 3. Claude Review ワークフロー（claude_review.yml）

PR が作成・更新された際に自動でコードレビューを実行するワークフローです。

### `.github/workflows/claude_review.yml`

```yaml
name: Claude Review

on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: write
  issues: write
  actions: read
  id-token: write

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
          fetch-depth: 0

      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: "/review"
          track_progress: true
          allowed_bots: "claude[bot]"
          claude_args: |
            --model haiku
            --max-turns 25
            --allowedTools "Bash(gh pr list:*),Bash(gh pr view:*),Bash(gh pr diff:*),Bash(gh pr comment:*)"
```

---

## 4. Reusable Workflows（提供側向け）

他のリポジトリから呼び出し可能な再利用可能ワークフローです。

### `.github/workflows/reusable-claude.yml`

INSTALLATION.md の [Reusable Workflow ファイル](./INSTALLATION.md#reusable-workflow-ファイル) セクションを参照してください。

---

## セットアップ手順

### 1. シークレットの設定

1. リポジトリの Settings → Secrets and variables → Actions
2. "New repository secret" をクリック
3. Name: `CLAUDE_CODE_OAUTH_TOKEN`
4. Value: Claude Code の OAuth トークン

### 2. ワークフローファイルの配置

上記のワークフローファイルを `.github/workflows/` ディレクトリに配置します。

```bash
# ディレクトリ構造
.github/
└── workflows/
    ├── claude.yml
    ├── claude_review.yml
    ├── lint-scripts.yml
    └── sync_templates.yml  # オプション
```

### 3. 動作確認

- Issue または PR でコメント: `@claude こんにちは`
- PR を作成して自動レビューが動作することを確認

---

## トラブルシューティング

### ワークフローが実行されない

- `CLAUDE_CODE_OAUTH_TOKEN` シークレットが設定されているか確認
- ワークフローファイルの構文エラーを確認
- 必要な permissions が設定されているか確認

### 権限エラー

permissions セクションが正しく設定されているか確認：

```yaml
permissions:
  contents: write      # ファイル変更に必要
  pull-requests: write # PR 操作に必要
  issues: write        # Issue コメントに必要
  id-token: write      # 認証に必要
```

### ShellCheck の警告

ShellCheck の警告が多すぎる場合は、severity を調整：

```yaml
- name: Run ShellCheck
  uses: ludeeus/action-shellcheck@master
  with:
    scandir: './scripts'
    severity: error  # warning → error に変更
```
