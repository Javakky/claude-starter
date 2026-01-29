# Claude Starter - インストールガイド

このドキュメントでは、Claude Starter を任意のリポジトリに導入する方法を説明します。

## 導入方法の選択

| 方法 | 推奨ケース | 難易度 |
|------|-----------|--------|
| [インストールスクリプト](#方法1-インストールスクリプト推奨) | 新規プロジェクト、フル機能が必要 | ⭐ |
| [Reusable Workflows](#方法2-reusable-workflows) | CI のみ必要、既存設定を維持したい | ⭐⭐ |
| [手動コピー](#方法3-手動コピー) | 部分的なカスタマイズが必要 | ⭐⭐⭐ |

---

## 方法1: インストールスクリプト（推奨）

最も簡単な方法です。言語・フレームワークを問わず利用できます。

> ⚠️ **セキュリティに関する注意**: `curl | bash` パターンを実行する前に、必ずスクリプトの内容を確認してください。信頼できるソース（公式 GitHub リポジトリの raw content URL）からのみダウンロードしてください。不安な場合は、まずスクリプトをダウンロードして内容を確認してから実行することを推奨します。
>
> ```bash
> # スクリプトの内容を確認してから実行する方法
> curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh -o install.sh
> cat install.sh  # 内容を確認
> chmod +x install.sh && ./install.sh
> ```

### 基本インストール

```bash
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash
```

### オプション付きインストール

```bash
# バージョン指定
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- --version v1.0.0

# Workflows のみ（.claude/ をスキップ）
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- --no-claude

# .claude/ のみ（Workflows をスキップ）
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- --no-workflows

# 強制上書き
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- --force

# 確認のみ（dry-run）
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- --dry-run
```

### インストールされるファイル

```
your-project/
├── .claude/
│   ├── commands/
│   │   ├── implement.md
│   │   ├── fix_ci.md
│   │   ├── review_prep.md
│   │   ├── refactor_by_lint.md
│   │   └── orchestrator.md
│   └── rules/
│       ├── 00_scope.md
│       ├── 10_workflow.md
│       ├── 20_quality.md
│       ├── 30_security.md
│       └── 40_output.md
├── .github/
│   ├── workflows/
│   │   ├── claude.yml
│   │   ├── claude_review.yml
│   │   └── sync_templates.yml
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/
│       └── agent_task.md
├── scripts/
│   └── sync_templates.py
└── docs/
    └── agent/
        ├── TASK.md
        └── PR.md
```

### 更新方法

```bash
# 最新版に更新
./scripts/update.sh

# 特定バージョンに更新
./scripts/update.sh --version v1.0.0

# バックアップなしで更新
./scripts/update.sh --no-backup
```

---

## 方法2: Reusable Workflows

GitHub Actions の Reusable Workflows を使う方法です。CI 部分のみ必要な場合に便利です。

> **Note**: Reusable Workflows を利用するには、まず `claude-starter` リポジトリに以下のワークフローファイルを追加する必要があります。
> - `.github/workflows/reusable-claude.yml`
> - `.github/workflows/reusable-claude-review.yml`
>
> これらのファイルの内容は [Reusable Workflow ファイル](#reusable-workflow-ファイル) セクションを参照してください。

### Claude Code ワークフロー

`.github/workflows/claude.yml` を作成:

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  claude:
    uses: Javakky/claude-starter/.github/workflows/reusable-claude.yml@master
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    with:
      # オプション（省略可）
      default_model: 'sonnet'
      default_max_turns: 10
      timeout_minutes: 30
      # プロジェクト固有のツールを許可
      allowed_tools: |
        Bash(npm run lint:*)
        Bash(npm run test:*)
        Bash(npm run build:*)
```

### Claude Review ワークフロー

`.github/workflows/claude_review.yml` を作成:

```yaml
name: Claude Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    uses: Javakky/claude-starter/.github/workflows/reusable-claude-review.yml@master
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    with:
      # オプション（省略可）
      model: 'haiku'
      max_turns: 25
      prompt: '/review'
```

### 入力パラメータ一覧

#### reusable-claude.yml

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `default_model` | デフォルトの Claude モデル | `sonnet` |
| `default_max_turns` | デフォルトの最大ターン数 | `10` |
| `allowed_tools` | 許可する追加ツール（改行区切り） | `''` |
| `timeout_minutes` | ジョブのタイムアウト（分） | `30` |
| `checkout_fetch_depth` | git checkout の fetch-depth | `0` |

#### reusable-claude-review.yml

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `model` | Claude モデル | `haiku` |
| `max_turns` | 最大ターン数 | `25` |
| `prompt` | レビュープロンプト | `/review` |
| `allowed_bots` | 許可するボット | `claude[bot]` |
| `checkout_fetch_depth` | git checkout の fetch-depth | `0` |

---

## 方法3: 手動コピー

必要なファイルのみを手動でコピーする方法です。

### 最小構成（CI のみ）

1. `.github/workflows/claude.yml` をコピー
2. リポジトリの Secrets に `CLAUDE_CODE_OAUTH_TOKEN` を設定

### 推奨構成

1. `.claude/` ディレクトリ全体をコピー
2. `.github/workflows/claude.yml` をコピー
3. `.github/workflows/claude_review.yml` をコピー
4. リポジトリの Secrets に `CLAUDE_CODE_OAUTH_TOKEN` を設定

---

## 必須設定

### 1. CLAUDE_CODE_OAUTH_TOKEN の設定

1. リポジトリの Settings → Secrets and variables → Actions
2. "New repository secret" をクリック
3. Name: `CLAUDE_CODE_OAUTH_TOKEN`
4. Value: Claude Code の OAuth トークン

### 2. プロジェクト固有のカスタマイズ

#### `.github/workflows/claude.yml`

プロジェクトで使用する言語・フレームワークに応じて `allowedTools` を編集:

```yaml
# PHP プロジェクト
--allowedTools "Bash(vendor/bin/php-cs-fixer fix:*)" "Bash(vendor/bin/phpstan analyse:*)" "Bash(vendor/bin/phpunit tests:*)"

# Node.js プロジェクト
--allowedTools "Bash(npm run lint:*)" "Bash(npm run test:*)" "Bash(npm run build:*)"

# Python プロジェクト
--allowedTools "Bash(pytest:*)" "Bash(ruff check:*)" "Bash(mypy:*)"

# Scala プロジェクト
--allowedTools "Bash(sbt scalafixAll)" "Bash(sbt scalafmtAll)" "Bash(sbt test)"
```

#### `.claude/rules/`

プロジェクト固有のルールを追加・編集:

- `00_scope.md` - 変更可能/不可の範囲
- `20_quality.md` - 品質基準
- `30_security.md` - セキュリティルール

---

## トラブルシューティング

### インストールスクリプトが動かない

```bash
# スクリプトを直接ダウンロードして実行
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

### 権限エラー

```bash
# 書き込み権限を確認
ls -la .github/
ls -la .claude/
```

### 既存ファイルとの競合

```bash
# --force オプションで上書き
./scripts/install.sh --force

# または update.sh を使用（バックアップ付き）
./scripts/update.sh
```

---

## 各方法のメリット・デメリット

### インストールスクリプト

**メリット**
- ✅ 最も簡単
- ✅ 言語非依存
- ✅ バージョン管理可能
- ✅ 更新が容易

**デメリット**
- ❌ curl + bash が必要
- ❌ ネットワーク依存

### Reusable Workflows

**メリット**
- ✅ ファイル管理が最小
- ✅ 常に最新
- ✅ カスタマイズ可能

**デメリット**
- ❌ CI 部分のみ
- ❌ `.claude/` は別途必要

### 手動コピー

**メリット**
- ✅ 完全なコントロール
- ✅ 部分的な導入が可能

**デメリット**
- ❌ 更新が手動
- ❌ 作業量が多い

---

## Reusable Workflow ファイル

Reusable Workflows を利用する場合は、`claude-starter` リポジトリに以下のファイルを追加してください。

### `.github/workflows/reusable-claude.yml`

<details>
<summary>クリックして展開</summary>

```yaml
# Reusable Claude Code Workflow
# 他のリポジトリから呼び出し可能な再利用可能ワークフロー

name: Reusable Claude Code

on:
  workflow_call:
    inputs:
      default_model:
        description: 'デフォルトの Claude モデル (sonnet/opus/haiku)'
        type: string
        default: 'sonnet'
      default_max_turns:
        description: 'デフォルトの最大ターン数'
        type: number
        default: 10
      allowed_tools:
        description: '許可する追加ツール（改行区切り）'
        type: string
        default: ''
      timeout_minutes:
        description: 'ジョブのタイムアウト（分）'
        type: number
        default: 30
      checkout_fetch_depth:
        description: 'git checkout の fetch-depth'
        type: number
        default: 0
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN:
        description: 'Claude Code OAuth Token'
        required: true

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
    timeout-minutes: ${{ inputs.timeout_minutes }}
    runs-on: ubuntu-latest
    if: contains(github.event.comment.body, '@claude')

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: ${{ inputs.checkout_fetch_depth }}

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
              body.includes("[haiku]") ? "haiku" : "${{ inputs.default_model }}";

            // ターン数解析
            const m = body.match(/\[(?:turns|max-turns)=(\d+)\]/);
            const maxTurns = m ? Number(m[1]) : ${{ inputs.default_max_turns }};

            core.setOutput("model", model);
            core.setOutput("max_turns", String(maxTurns));

      - name: Build allowed tools
        id: tools
        run: |
          TOOLS=""
          CUSTOM_TOOLS="${{ inputs.allowed_tools }}"

          if [ -n "$CUSTOM_TOOLS" ]; then
            while IFS= read -r tool; do
              if [ -n "$tool" ]; then
                TOOLS="$TOOLS --allowedTools \"$tool\""
              fi
            done <<< "$CUSTOM_TOOLS"
          fi

          echo "tools=$TOOLS" >> $GITHUB_OUTPUT

      - name: Run Claude Code Action
        uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          claude_args: >-
            --model ${{ steps.opts.outputs.model }}
            --max-turns ${{ steps.opts.outputs.max_turns }}
            ${{ steps.tools.outputs.tools }}
```

</details>

### `.github/workflows/reusable-claude-review.yml`

<details>
<summary>クリックして展開</summary>

```yaml
# Reusable Claude Review Workflow
# 他のリポジトリから呼び出し可能な再利用可能レビューワークフロー

name: Reusable Claude Review

on:
  workflow_call:
    inputs:
      model:
        description: 'Claude モデル (sonnet/opus/haiku)'
        type: string
        default: 'haiku'
      max_turns:
        description: '最大ターン数'
        type: number
        default: 25
      prompt:
        description: 'レビュープロンプト'
        type: string
        default: '/review'
      allowed_bots:
        description: '許可するボット'
        type: string
        default: 'claude[bot]'
      checkout_fetch_depth:
        description: 'git checkout の fetch-depth'
        type: number
        default: 0
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN:
        description: 'Claude Code OAuth Token'
        required: true

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
          fetch-depth: ${{ inputs.checkout_fetch_depth }}

      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: "${{ inputs.prompt }}"
          track_progress: true
          allowed_bots: "${{ inputs.allowed_bots }}"
          claude_args: |
            --model ${{ inputs.model }}
            --max-turns ${{ inputs.max_turns }}
            --allowedTools "Bash(gh pr list:*),Bash(gh pr view:*),Bash(gh pr diff:*),Bash(gh pr comment:*)"
```

</details>
