# Claude Starter

任意のリポジトリで Claude Code による自動開発・レビュー機能を簡単に導入できるセットアップツール。言語やフレームワークに依存しません。

## 概要

Claude Starter は以下を提供します：

- **インストールスクリプト** (`scripts/install.sh`): ワンライナーで全セットアップを実行
- **更新スクリプト** (`scripts/update.sh`): 既存インストールを簡単に更新
- **GitHub Workflows**: Issue/PR コメントへの自動応答、自動レビュー機能
- **Claude 設定セット** (`.claude/`): 開発フロー、品質基準、セキュリティルール
- **ドキュメント**: インストールガイド、設定例、比較資料

## クイックスタート

### 方法1: インストールスクリプト（推奨）

最も簡単な方法です。言語・フレームワークを問わず利用できます。

```bash
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash
```

> ⚠️ **セキュリティに関する注意**: スクリプトの内容を確認してから実行することをお勧めします。
>
> ```bash
> curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh -o install.sh
> cat install.sh  # 内容を確認
> chmod +x install.sh && ./install.sh
> ```

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

### 更新方法

```bash
# 最新版に更新
./scripts/update.sh

# 特定バージョンに更新
./scripts/update.sh --version v1.0.0

# バックアップなしで更新
./scripts/update.sh --no-backup
```

## インストールされるファイル

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

## 必須設定

### CLAUDE_CODE_OAUTH_TOKEN の設定

1. リポジトリの Settings → Secrets and variables → Actions
2. "New repository secret" をクリック
3. Name: `CLAUDE_CODE_OAUTH_TOKEN`
4. Value: [Claude Code の OAuth トークン](https://claude.ai/claude-code)を取得して入力

### プロジェクト固有のカスタマイズ

#### `.github/workflows/claude.yml`

プロジェクトで使用する言語・フレームワークに応じて `allowedTools` を編集：

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

プロジェクト固有のルールを追加・編集：

- `00_scope.md` - 変更可能/不可の範囲
- `20_quality.md` - 品質基準
- `30_security.md` - セキュリティルール

## Reusable Workflows を使用する場合

GitHub Actions の Reusable Workflows を使う方法です。CI 部分のみ必要な場合に便利です。

### Claude Code ワークフロー

`.github/workflows/claude.yml` を作成：

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

`.github/workflows/claude_review.yml` を作成：

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

## ドキュメント

詳細な情報は以下を参照してください：

- [**INSTALLATION.md**](docs/INSTALLATION.md) - 詳細なインストールガイド、Reusable Workflows の入力パラメータ
- [**PACKAGE_COMPARISON.md**](docs/PACKAGE_COMPARISON.md) - シェルスクリプト vs 他のパッケージ配布方法の比較
- [**GITHUB_WORKFLOWS.md**](docs/GITHUB_WORKFLOWS.md) - GitHub Workflows 設定ガイド

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。

## 使用している技術

- **bash** - インストール・更新スクリプト
- **GitHub Actions** - 自動開発・レビュー機能
- **Claude Code** - AI による開発支援

## サポート

問題が発生した場合は、以下をご確認ください：

1. [GitHub Issues](https://github.com/Javakky/claude-starter/issues) で既知の問題を確認
2. [INSTALLATION.md](docs/INSTALLATION.md) のトラブルシューティングセクション
3. スクリプトのヘルプを確認: `./scripts/install.sh --help`
