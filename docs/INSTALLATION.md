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
│   ├── actions/
│   │   ├── prepare-claude-context/ # イベントを解析し、実行を制御する
│   │   ├── run-claude/             # 実装タスクを実行する
│   │   ├── run-claude-review/      # レビュータスクを実行する
│   │   └── cancel-claude-runs/     # 既存のワークフロー実行をキャンセルする
│   ├── workflows/
│   │   ├── claude.yml              # @claude コメントによる実装タスクを実行するWF
│   │   ├── claude-review.yml       # PRの自動レビューを実行するWF
│   │   └── sync_templates.yml      # .claude/ ディレクトリを更新するWF
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/
│       └── agent_task.md
├── scripts/
│   └── sync_templates.py
│   ├── install.sh        # このインストールスクリプト
├── docs/
│   └── agent/
│       ├── TASK.md
│       └── PR.md
└── CLAUDE.md
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

`claude.yml` は、Claude にコード生成や修正を指示するためのワークフローです。プロジェクトの技術スタックに合わせて、このファイルの環境設定部分を編集する必要があります。

例えば、Node.js プロジェクトの場合、`npm install` を実行するステップを追加します。

#### `.github/workflows/claude.yml` のカスタマイズ例

```yaml
# ...
      - name: Checkout code
        if: steps.prep.outputs.should_run == 'true'
        uses: actions/checkout@v4
        with:
          ref: ${{ steps.prep.outputs.head_sha }} # Falls back to default branch if head_sha is empty
          fetch-depth: 0

      # --- ▼ プロジェクトの環境設定をここに追加 ▼ ---
      - name: Set up Node.js
        if: steps.prep.outputs.should_run == 'true'
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        if: steps.prep.outputs.should_run == 'true'
        run: npm install
      # --- ▲ プロジェクトの環境設定をここに追加 ▲ ---

      - name: Run Claude
        if: steps.prep.outputs.should_run == 'true'
        uses: Javakky/claude-starter/.github/actions/run-claude@@REF@@
        with:
          issue_number: ${{ steps.prep.outputs.issue_number }}
          pr_number: ${{ steps.prep.outputs.pr_number }}
          comment_body: ${{ steps.prep.outputs.comment_body }}
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # 必要に応じてデフォルト値をオーバーライド
          # allowed_tools: |
          #   Bash(npm run lint)
          #   Bash(npm run test)
```

---

## Composite Actions の詳細

`claude-starter` は、ワークフローのロジックをカプセル化するために、いくつかの Composite Actions を提供します。

### `prepare-claude-context`

**役割**: ワークフローの"頭脳"です。GitHub のイベントを解析し、実行すべきタスク（実装 or レビュー or スキップ）を判断します。また、実行権限のチェック、PR情報の取得、重複実行の防止など、実行前の準備をすべて担当します。

| 入力 (`inputs`) | 説明 |
|---|---|
| `mode` | `implement` または `review` を指定し、ワークフローの目的を伝えます。 |
| `impl_workflow_id` | 実装ワークフローのファイル名（例: `claude-impl.yml`）。レビュー中に実装が実行されていないか確認するために使います。 |
| `skip_commit_prefixes` | レビューをスキップするコミットメッセージの接頭辞（例: `docs:,wip:`）。 |
| `allowed_comment_permissions` | コメントでの実行を許可するユーザー権限（例: `admin,write`）。 |

| 出力 (`outputs`) | 説明 |
|---|---|
| `should_run` | ワークフローを続行すべきか (`true`/`false`)。 |
| `issue_number` | ワークフローをトリガーした Issue または PR の番号。 |
| `pr_number` | 実行対象となるPRの番号（PRでない場合は空）。 |
| `head_sha`, `head_ref` | 実行対象となるPRのブランチ情報（PRでない場合は空）。 |
| `comment_body` | トリガーとなったコメントの本文。 |


### `run-claude`

**役割**: 実装タスクを実行します。Issue コメントからモデル指定（`[opus]`など）やターン数（`[turns=...]`など）を解析し、`anthropics/claude-code-action` を適切なパラメータで実行します。

| 入力 (`inputs`) | 説明 |
|---|---|
| `issue_number` | ワークフローをトリガーした Issue または PR の番号。 |
| `pr_number` | 実行対象となるPRの番号（新規PR作成の場合は空）。 |
| `comment_body` | トリガーとなったコメントの本文。 |
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 |
| `allowed_tools` | Claude に許可する追加のツール（改行区切り）。 |


### `run-claude-review`

**役割**: Pull Request の自動レビューを実行します。`anthropics/claude-code-action` をレビュー用の設定で実行します。

| 入力 (`inputs`) | 説明 |
|---|---|
| `issue_number` | ワークフローをトリガーした Issue または PR の番号。 |
| `pr_number` | レビュー対象のPR番号。 |
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 |
| `model` | レビューに使用するモデル (`haiku`, `sonnet`, `opus`)。 |
| `prompt` | レビューを依頼する際のプロンプト（デフォルト: `/review`）。 |


### `cancel-claude-runs`

**役割**: 指定されたワークフローの実行をキャンセルします。主に、実装タスク(`claude.yml`)が開始されたときに、進行中のレビュータスク(`claude-review.yml`)を停止するために使用されます。

| 入力 (`inputs`) | 説明 |
|---|---|
| `workflow_id` | キャンセル対象のワークフローのファイル名（例: `claude-review.yml`）。 |
| `pr_number` | 対象となる Pull Request の番号。 |

---

## 手動での導入

インストールスクリプトを使わずに、必要なファイルを手動でリポジトリに配置することも可能です。

### 1. 必要なファイルをコピーする

`claude-starter` リポジトリから、以下のディレクトリとファイルをあなたのプロジェクトにコピーします。

-   `.claude/` (ディレクトリ全体)
-   `.github/actions/` (ディレクトリ全体)
-   `examples/.github/workflows/claude.yml.template` を `.github/workflows/claude.yml` としてコピー
-   `examples/.github/workflows/claude-review.yml.template` を `.github/workflows/claude-review.yml` としてコピー

### 2. ワークフローを調整する

コピーした `.github/workflows/claude.yml` と `claude-review.yml` を開き、`uses:` のパスを調整します。

`@@REF@@` の部分を、使用したい `claude-starter` のブランチ名やタグ（例: `@master`）に置き換えるか、ローカルのアクションを参照するように変更します。

**変更前:**
`uses: Javakky/claude-starter/.github/actions/prepare-claude-context@@REF@@`

**変更後 (ローカル参照):**
`uses: ./.github/actions/prepare-claude-context`

### 3. 必須設定を行う

上記「必須設定」セクションの指示に従い、`CLAUDE_CODE_OAUTH_TOKEN` の設定と、ワークフローのカスタマイズを行ってください。
