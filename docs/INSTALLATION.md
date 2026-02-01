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
name: Claude

on:
  issue_comment:
    types: [created]

# 必要な権限
permissions:
  contents: write
  pull-requests: write
  issues: write
  actions: write # 実行中のワークフローをキャンセルするために必要

jobs:
  claude:
    runs-on: ubuntu-latest
    if: contains(github.event.comment.body, '@claude')
    steps:
      # 1. PR情報を取得
      - name: Get PR info
        id: pr_info
        uses: actions/github-script@v7
        with:
          script: |
            # ... (PR情報を取得するスクリプト)

      # 2. 競合するワークフローをハンドル
      - name: Handle conflicting workflows
        uses: actions/github-script@v7
        with:
          script: |
            # ... (競合ワークフローをキャンセルするスクリプト)

      # 3. リポジトリをチェックアウト
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # 4. プロジェクトの環境設定 (例: Node.js)
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm install

      # 5. Claude を実行
      - name: Run Claude
        uses: Javakky/claude-starter/.github/actions/run-claude@master
        with:
          github_token: ${{ github.token }}
          comment_body: ${{ github.event.comment.body }}
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # 必要に応じてデフォルト値をオーバーライド
          # default_model: 'opus'
          # allowed_tools: |
          #   Bash(npm run lint)
          #   Bash(npm run test)
```

---

## Composite Actions の詳細

（このセクションは変更ありません）

---

## 手動での導入

（このセクションは変更ありません）
