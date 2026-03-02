# Claude Starter - インストールガイド

このドキュメントでは、Claude Starter を任意のリポジトリに導入する方法を説明します。

## 導入方法

最も簡単で推奨される方法は、[copier](https://copier.readthedocs.io/) を使用することです。

---

## copier によるインストール（推奨）

### 前提条件

- Python 3.10 以上
- Git 2.27 以上

### copier のインストール

```bash
# pipx を使用（推奨）
pipx install copier

# または pip
pip install copier
```

### 実行方法

ターミナルで以下のコマンドを実行してください。

```bash
copier copy gh:Javakky/claude-starter .
```

対話形式で以下の質問に回答します:

| 質問 | 説明 | デフォルト |
|-----|------|----------|
| `ref` | GitHub Actions で参照するバージョン | `@master` |
| `install_claude` | `.claude/` ディレクトリをインストール | `true` |
| `install_workflows` | GitHub Workflows をインストール | `true` |
| `install_docs` | `docs/agent/` をインストール | `true` |
| `install_scripts` | `scripts/` をインストール | `true` |

### インストールオプション

```bash
# デフォルト値で対話なしインストール
copier copy gh:Javakky/claude-starter . --defaults

# 特定のバージョン（タグ）を指定
copier copy gh:Javakky/claude-starter --vcs-ref v1.0.0 .

# Workflows をスキップ
copier copy gh:Javakky/claude-starter . -d install_workflows=false

# .claude/ をスキップ
copier copy gh:Javakky/claude-starter . -d install_claude=false
```

### インストールされるファイル

```
your-project/
├── .claude/
│   ├── commands/
│   │   ├── implement.md, fix_ci.md, review_prep.md, ...
│   └── rules/
│       ├── 00_scope.md, 10_workflow.md, 20_quality.md, ...
├── .github/
│   ├── workflows/
│   │   ├── claude.yml              # @claude コメントによる実装タスクを実行
│   │   ├── claude-review.yml       # PRの自動レビューを実行
│   │   ├── claude-plan.yml         # @claude [plan] によるプラン作成
│   │   ├── claude-breakdown.yml    # @claude [breakdown] によるIssue分解
│   │   ├── claude-milestone.yml    # Milestone作成時にタスク分解用Issueを自動作成
│   │   └── sync_templates.yml      # テンプレート同期
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/
│       └── agent_task.md
├── docs/
│   └── agent/
│       ├── TASK.md, PR.md
│       ├── PLAN_PROMPT.md, BREAKDOWN_PROMPT.md
├── scripts/
│   └── sync_templates.py
├── CLAUDE.md
└── .copier-answers.yml             # copier の設定（更新時に使用）
```

### プロジェクトの更新

テンプレートが更新されたとき、既存プロジェクトを更新:

```bash
# 変更点を確認しながら更新
copier update

# 特定バージョンに更新
copier update --vcs-ref v2.0.0
```

> `.copier-answers.yml` に前回の回答が保存されているため、同じ質問に再度回答する必要はありません。

---

## 必須設定

インストール後、以下の設定を行ってください。

### 1. リポジトリシークレットの設定

Claude を動作させるには、OAuth トークンを GitHub リポジトリのシークレットに登録する必要があります。

1. リポジトリの `Settings` > `Secrets and variables` > `Actions` に移動します。
2. `New repository secret` をクリックします。
3. **Name**: `CLAUDE_CODE_OAUTH_TOKEN`
4. **Value**: あなたの Claude Code OAuth トークンを入力します。

#### Codex 用のシークレット（オプション）

`@codex` メンションによる [Codex CLI](https://github.com/openai/codex) 連携を使用する場合は、以下のいずれかのシークレットを追加で登録します。API キーの取得方法は [OpenAI Platform](https://platform.openai.com/api-keys) を参照してください。

| シークレット名 | 説明 | 必須 |
|---|---|---|
| `CODEX_CODE_OAUTH_TOKEN` | Codex（OpenAI）の API キー | いずれか一方 |
| `CODEX_AUTH_JSON` | Codex の認証情報（`~/.codex/auth.json` を Base64 エンコードした値） | いずれか一方 |

**`CODEX_AUTH_JSON` の作成方法:**

```bash
# auth.json を Base64 エンコードしてコピー
base64 -w 0 ~/.codex/auth.json
```

> **Note**: `CODEX_CODE_OAUTH_TOKEN` は環境変数 `OPENAI_API_KEY` として Codex CLI に渡されます。`CODEX_AUTH_JSON` は `~/.codex/auth.json` にデコードして配置されます。両方設定した場合は `CODEX_AUTH_JSON` が優先されます。

### 2. ワークフローのカスタマイズ

`claude.yml` は、Claude にコード生成や修正を指示するためのワークフローです。プロジェクトの技術スタックに合わせて、環境設定部分を編集してください。

#### `.github/workflows/claude.yml` のカスタマイズ例

```yaml
      # --- プロジェクトの環境設定をここに追加 ---
      # 例: Node.js
      # - name: Set up Node.js
      #   uses: actions/setup-node@v4
      #   with:
      #     node-version: '20'
      #     cache: 'npm'
      #
      # - name: Install dependencies
      #   run: npm install
      # ------------------------------------

      - name: Run Claude (implement)
        if: steps.prep.outputs.should_run == 'true'
        uses: Javakky/claude-starter/.github/actions/run-claude@master
        with:
          comment_body: ${{ steps.prep.outputs.comment_body }}
          mention_type: ${{ steps.prep.outputs.mention_type }}
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # Codex 連携を有効にする場合は以下を追加
          codex_code_oauth_token: ${{ secrets.CODEX_CODE_OAUTH_TOKEN }}
          codex_auth_json: ${{ secrets.CODEX_AUTH_JSON }}
          # 必要に応じてデフォルト値をオーバーライド
          # default_model: 'opus'
          # default_max_turns: 20
          # allowed_tools: |
          #   Bash(npm run lint)
          #   Bash(npm run test)
```

---

## Composite Actions の詳細

`claude-starter` は、ワークフローのロジックをカプセル化するために、いくつかの Composite Actions を提供します。これらは `Javakky/claude-starter/.github/actions/` から参照されます。

### `prepare-claude-context`

**役割**: ワークフローの"頭脳"です。GitHub のイベントを解析し、実行すべきタスク（実装 or レビュー or スキップ）を判断します。また、実行権限のチェック、PR情報の取得、重複実行の防止など、実行前の準備をすべて担当します。

| 入力 (`inputs`) | 説明 |
|---|---|
| `mode` | `implement` / `review` / `plan` / `breakdown` を指定し、ワークフローの目的を伝えます。 |
| `impl_workflow_id` | 実装ワークフローのファイル名（例: `claude.yml`）。レビュー中に実装が実行されていないか確認するために使います。 |
| `skip_commit_prefixes` | レビューをスキップするコミットメッセージの接頭辞（例: `docs:,wip:`）。 |
| `allowed_comment_permissions` | コメントでの実行を許可するユーザー権限（例: `admin,write`）。 |

| 出力 (`outputs`) | 説明 |
|---|---|
| `should_run` | ワークフローを続行すべきか (`true`/`false`)。 |
| `issue_number` | ワークフローをトリガーした Issue または PR の番号。 |
| `pr_number` | 実行対象となるPRの番号（PRでない場合は空）。 |
| `head_sha`, `head_ref` | 実行対象となるPRのブランチ情報（PRでない場合は空）。 |
| `comment_body` | トリガーとなったコメントの本文。 |
| `milestone_number` | Milestone 番号（breakdown モードで Issue に milestone が紐付いている場合）。 |
| `milestone_title` | Milestone タイトル（breakdown モードで Issue に milestone が紐付いている場合）。 |


### `run-claude`

**役割**: 実装タスクを実行します。Issue コメントからモデル指定（`[opus]`など）やターン数（`[turns=...]`など）を解析し、`anthropics/claude-code-action` を適切なパラメータで実行します。`mention_type` が `codex` の場合は `run-codex` に委譲します。

| 入力 (`inputs`) | 説明 |
|---|---|
| `issue_number` | ワークフローをトリガーした Issue または PR の番号。 |
| `pr_number` | 実行対象となるPRの番号（新規PR作成の場合は空）。 |
| `comment_body` | トリガーとなったコメントの本文。 |
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 |
| `codex_code_oauth_token` | Codex Code OAuth Token / API キー（`mention_type` が `codex` の場合に使用）。 |
| `codex_auth_json` | Codex 認証情報（`auth.json` の Base64 エンコード値）。 |
| `mention_type` | メンションの種類（`claude` または `codex`）。デフォルト: `claude`。 |
| `head_ref` | PR の head ブランチ名（Codex のブランチリンク表示に使用）。 |
| `allowed_tools` | Claude に許可する追加のツール（改行区切り）。 |


### `run-claude-review`

**役割**: Pull Request の自動レビューを実行します。`anthropics/claude-code-action` をレビュー用の設定で実行します。`mention_type` が `auto`（デフォルト）の場合は Claude を優先し、Claude トークンがなければ Codex にフォールバックします。

| 入力 (`inputs`) | 説明 |
|---|---|
| `issue_number` | ワークフローをトリガーした Issue または PR の番号。 |
| `pr_number` | レビュー対象のPR番号。 |
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 |
| `codex_code_oauth_token` | Codex Code OAuth Token / API キー。 |
| `codex_auth_json` | Codex 認証情報（`auth.json` の Base64 エンコード値）。 |
| `mention_type` | メンションの種類（`claude`, `codex`, `auto`）。デフォルト: `auto`（Claude 優先でフォールバック）。 |
| `head_ref` | PR の head ブランチ名（Codex のブランチリンク表示に使用）。 |
| `model` | レビューに使用するモデル (`haiku`, `sonnet`, `opus`)。 |
| `prompt` | レビューを依頼する際のプロンプト（デフォルト: `/review`）。 |


### `run-claude-plan`

**役割**: Issue に対して実装プランを作成し、Issue コメントに投稿します。コードの実装は行いません。Issue コメントで `@claude [plan]` または `@codex [plan]` と書くと起動します。

コメント本文に `[sonnet]`/`[opus]`/`[haiku]` や `[max-turns=N]` を含めることでモデルとターン数を上書きできます。

| 入力 (`inputs`) | 説明 |
|---|---|
| `comment_body` | トリガーとなったコメントの本文。モデル・ターン数の解析に使用。 |
| `issue_number` | プランを投稿する Issue 番号。 |
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 |
| `codex_code_oauth_token` | Codex Code OAuth Token / API キー。 |
| `codex_auth_json` | Codex 認証情報（`auth.json` の Base64 エンコード値）。 |
| `mention_type` | メンションの種類（`claude` または `codex`）。デフォルト: `claude`。 |
| `github_token` | GitHub トークン（省略時は App モードで動作）。 |
| `default_model` | デフォルトのモデル（デフォルト: `opus`）。 |
| `default_max_turns` | デフォルトのターン数（デフォルト: `50`）。 |
| `allowed_tools` | Claude に許可する追加のツール（改行区切り）。 |


### `run-claude-breakdown`

**役割**: Issue の最新プランコメントを読み取り、並行作業可能な粒度でタスクを分解して GitHub Issue を作成し、同じ Milestone に追加します。Issue コメントで `@claude [breakdown]` または `@codex [breakdown]` と書くと起動します。

**重要**: breakdown は Milestone に紐づいた Issue でのみ実行できます。Milestone に紐づいていない Issue でコマンドを実行すると、警告メッセージが表示されスキップされます。

分解は4フェーズで実行されます: プラン取得 → タスク草案作成 → 自己レビュー（網羅性・並行性・粒度チェック）→ Issue 作成 & Milestone 追加。

Codex で実行する場合、サンドボックス環境で `gh` CLI が使用できないため、`.codex-issues.json` に Issue 定義を書き出し、ワークフロー側で Issue を自動作成します。

コメント本文に `[sonnet]`/`[opus]`/`[haiku]` や `[max-turns=N]` を含めることでモデルとターン数を上書きできます。

| 入力 (`inputs`) | 説明 |
|---|---|
| `comment_body` | トリガーとなったコメントの本文。モデル・ターン数の解析に使用。 |
| `issue_number` | プランコメントを参照する Issue 番号。 |
| `milestone_number` | 分解したタスクを追加する Milestone 番号。 |
| `milestone_title` | Milestone タイトル。 |
| `claude_code_oauth_token` | Claude Code の OAuth トークン。 |
| `codex_code_oauth_token` | Codex Code OAuth Token / API キー。 |
| `codex_auth_json` | Codex 認証情報（`auth.json` の Base64 エンコード値）。 |
| `mention_type` | メンションの種類（`claude` または `codex`）。デフォルト: `claude`。 |
| `github_token` | GitHub トークン（省略時は App モードで動作）。 |
| `default_model` | デフォルトのモデル（デフォルト: `opus`）。 |
| `default_max_turns` | デフォルトのターン数（デフォルト: `100`）。 |
| `allowed_tools` | Claude に許可する追加のツール（改行区切り）。 |


### `run-codex`

**役割**: [Codex CLI](https://github.com/openai/codex) のセットアップと実行を行う共通アクションです。利用可能なモデルについては [OpenAI 公式モデル一覧](https://platform.openai.com/docs/models) を参照してください。`run-claude`、`run-claude-plan`、`run-claude-review`、`run-claude-breakdown` が `mention_type=codex` の場合に内部的に使用します。GitHub 連携機能（進捗コメント投稿、コード変更の自動コミット・プッシュ）を備えています。

認証方式は API キー（`OPENAI_API_KEY` 環境変数として設定）と `auth.json`（`~/.codex/auth.json` に配置）の 2 種類に対応しています。

| 入力 (`inputs`) | 説明 |
|---|---|
| `codex_code_oauth_token` | Codex Code OAuth Token / API キー。 |
| `codex_auth_json` | Codex 認証情報（`auth.json` の Base64 エンコード値）。 |
| `github_token` | GitHub トークン（コメント投稿・gh CLI 認証に使用）。 |
| `prompt` | Codex に渡すプロンプト。 |
| `comment_body` | トリガーコメントの本文（モデル・推論レベルの自動解決に使用）。 |
| `issue_number` | コメントを投稿する Issue/PR 番号。 |
| `pr_number` | PR 番号（PR コンテキストの取得に使用）。 |
| `head_ref` | PR の head ブランチ名。 |
| `auto_commit` | Codex 実行後にコード変更を自動コミット・プッシュするか（デフォルト: `true`）。 |
| `create_branch` | 実行前に新しいブランチを作成するか（デフォルト: `false`）。 |
| `branch_prefix` | 作成するブランチの接頭辞（デフォルト: `codex/`）。 |
| `default_model` | デフォルトの Codex モデル（デフォルト: `gpt-5.3-codex`）。コメント本文で `[model=xxx]` の指定がない場合に使用。 |
| `reasoning_effort` | 推論レベル（`minimal`, `low`, `medium`, `high`, `xhigh`）。 |

| 出力 (`outputs`) | 説明 |
|---|---|
| `codex_response` | Codex の実行結果サマリー。 |


### `cancel-claude-runs`

**役割**: 指定されたワークフローの実行をキャンセルします。主に、実装タスク(`claude.yml`)が開始されたときに、進行中のレビュータスク(`claude-review.yml`)を停止するために使用されます。

| 入力 (`inputs`) | 説明 |
|---|---|
| `workflow_id` | キャンセル対象のワークフローのファイル名（例: `claude-review.yml`）。 |
| `pr_number` | 対象となる Pull Request の番号。 |

---

## プロンプトのカスタマイズ

`run-claude-plan` と `run-claude-breakdown` は `docs/agent/` にあるプロンプトファイルを参照します。

| ファイル | 説明 |
|---|---|
| `docs/agent/PLAN_PROMPT.md` | plan 用のプロンプト |
| `docs/agent/BREAKDOWN_PROMPT.md` | breakdown 用のプロンプト |

### プレースホルダー

| プレースホルダー | 説明 |
|---|---|
| `{{ISSUE_NUMBER}}` | 対象の Issue 番号 |
| `{{MILESTONE_TITLE}}` | Milestone タイトル（breakdown のみ） |
