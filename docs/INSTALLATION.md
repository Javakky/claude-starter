# Claude Starter - インストールガイド

このドキュメントでは、Claude Starter を任意のリポジトリに導入する方法を説明します。

## 導入方法

最も簡単で推奨される方法は、インストールスクリプトを使用することです。これにより、必要なファイルがすべて自動で設定されます。

---

## インストールスクリプト（推奨）

このスクリプトは、Claude Starter の設定ファイルをリポジトリにダウンロードし、設定します。言語やフレームワークを問わず利用できます。

> ⚠️ **セキュリティに関する注意**: `curl | bash` パターンを実行する前に、必ずスクリプトの内容を確認してください。信頼できるソース（公式 GitHub リポジトリの raw content URL）からのみダウンロードしてください。不安な場合は、まずスクリプトをダウンロードして内容を確認してから実行することを推奨します。
>
> ```bash
> # スクリプトの内容を確認してから実行する方法
> curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh -o install.sh
> cat install.sh  # 内容を確認
> chmod +x install.sh && ./install.sh
> ```

### 実行方法

ターミナルで以下のコマンドを実行してください。

```bash
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash
```

### インストールされるファイル
スクリプトを実行すると、以下のファイルがプロジェクトに配置されます。

```
your-project/
├── .claude/
│   ├── commands/
│   │   ├── implement.md, fix_ci.md, review_prep.md, ...
│   └── rules/
│       ├── 00_scope.md, 10_workflow.md, 20_quality.md, ...
├── .github/
│   ├── workflows/
│   │   ├── claude.yml          # IssueコメントでClaudeを呼び出すWF
│   │   ├── claude_review.yml   # PRを自動レビューするWF
│   │   └── sync_templates.yml  # .claude/ ディレクトリを更新するWF
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/
│       └── agent_task.md
├── scripts/
│   └── sync_templates.py
├── docs/
│   └── agent/
│       ├── TASK.md
│       └── PR.md
└── CLAUDE.md                 # Claudeの基本的な使い方ガイド
```

### 更新方法

`claude-starter` の設定ファイルを最新版に更新するには、以下のスクリプトを実行します。

```bash
# 最新版に更新（既存ファイルはバックアップされます）
./scripts/update.sh

# 特定のバージョンに更新
./scripts/update.sh --version v1.2.0
```

---

## 必須設定

インストール後、以下の設定を行ってください。

### 1. リポジトリシークレットの設定

Claude を動作させるには、APIキー（OAuthトークン）を GitHub リポジトリのシークレットに登録する必要があります。

1.  リポジトリの `Settings` > `Secrets and variables` > `Actions` に移動します。
2.  `New repository secret` をクリックします。
3.  **Name**: `CLAUDE_CODE_OAUTH_TOKEN`
4.  **Value**: あなたの Claude Code OAuth トークンを入力します。

### 2. ワークフローのカスタマイズ

プロジェクトの技術スタックに合わせて、`claude.yml` を編集します。インストールスクリプトによって、ユーザーの最新の指示を優先するための重複実行防止ロジックが組み込まれたワークフローが生成されます。

以下は、Node.js プロジェクトのサンプルです。主に `steps` の環境設定部分や `allowed_tools` をプロジェクトに合わせて変更してください。

#### `.github/workflows/claude.yml` のサンプル

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]

# 必要な権限
permissions:
  contents: write
  pull-requests: read # PR情報を読み取るために必要
  issues: write
  actions: write # 実行中のワークフローをキャンセルするために必要

jobs:
  claude:
    runs-on: ubuntu-latest
    if: contains(github.event.comment.body, '@claude')
    steps:
      # 1. 実行準備と競合ワークフローの処理
      - name: Prepare Claude Run
        id: prepare
        uses: Javakky/claude-starter/.github/actions/prepare-claude-run@master

      # 2. リポジトリをチェックアウト
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          ref: ${{ steps.prepare.outputs.head_sha }}
          fetch-depth: 0

      # 3. プロジェクトの環境設定 (例: Node.js)
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm install

      # 4. Claude を実行
      - name: Run Claude
        uses: Javakky/claude-starter/.github/actions/run-claude@master
        with:
          github_token: ${{ github.token }}
          comment_body: ${{ github.event.comment.body }}
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # 必要に応じてデフォルト値をオーバーライド
          # allowed_tools: |
          #   Bash(npm run lint)
          #   Bash(npm run test)
```

---

## Composite Actions の詳細

`claude-starter` は、ワークフローのロジックをカプセル化するために、いくつかの Composite Actions を提供します。これらを直接利用することで、より柔軟なワークフローを構築することも可能です。

### `prepare-claude-run`

**役割**: Claude の実行を準備し、競合する古いワークフローをキャンセルします。

| 出力 (`outputs`) | 説明 |
|---|---|
| `head_sha` | 実行対象となる Pull Request の HEAD コミットの SHA。`actions/checkout` の `ref` に渡すために使います。 |

### `run-claude`

**役割**: Issue コメントを解析し、`anthropics/claude-code-action` を適切なパラメータで実行します。

| 入力 (`inputs`) | 説明 | 必須 | デフォルト値 |
|---|---|:---:|---|
| `github_token` | GitHub トークン。 | ✅ | |
| `comment_body` | トリガーとなったコメントの本文。 | ✅ | |
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 | ✅ | |
| `default_model` | デフォルトで使用するモデル。 | | `sonnet` |
| `default_max_turns` | デフォルトの最大ターン数。 | | `10` |
| `allowed_tools` | Claude に許可する追加のツール（改行区切り）。 | | (空) |

### `run-claude-review`

**役割**: Pull Request の自動レビューを実行します。

| 入力 (`inputs`) | 説明 | 必須 | デフォルト値 |
|---|---|:---:|---|
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 | ✅ | |
| `model` | レビューに使用するモデル。 | | `haiku` |
| `max_turns` | 最大ターン数。 | | `25` |
| `prompt` | レビューを依頼する際のプロンプト。 | | `/review` |
| `allowed_bots` | 応答を許可するボット名。 | | `claude[bot]` |

---

## 手動での導入

インストールスクリプトを使わずに、必要なファイルを手動でリポジトリに配置することも可能です。

### 1. 必要なファイルをコピーする

`claude-starter` リポジトリから、以下のディレクトリとファイルをあなたのプロジェクトにコピーします。

-   `.claude/` (ディレクトリ全体)
-   `.github/actions/` (ディレクトリ全体。`prepare-claude-run`, `run-claude`, `run-claude-review` を含みます)
-   `.github/workflows/claude.yml`
-   `.github/workflows/claude_review.yml`

### 2. ワークフローを調整する

コピーした `.github/workflows/claude.yml` と `claude_review.yml` を開き、`uses:` のパスを調整します。

`claude-starter` リポジトリを直接参照するのではなく、あなたのリポジトリ内にコピーしたローカルのアクションを参照するように変更します。

**変更前:**
`uses: Javakky/claude-starter/.github/actions/prepare-claude-run@master`

**変更後:**
`uses: ./.github/actions/prepare-claude-run`

### 3. 必須設定を行う

上記「必須設定」セクションの指示に従い、`CLAUDE_CODE_OAUTH_TOKEN` の設定と、ワークフローのカスタマイズを行ってください。
