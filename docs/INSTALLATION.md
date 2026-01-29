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
