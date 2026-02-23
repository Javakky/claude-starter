# Claude Starter - インストールガイド

このドキュメントでは、Claude Starter を任意のリポジトリに導入する方法を説明します。
Claude と Codex のどちらか、または両方を選んで運用できます。

## 導入方法

推奨は [copier](https://copier.readthedocs.io/) を使う方法です。

## copier によるインストール（推奨）

### 前提条件

- Python 3.10 以上
- Git 2.27 以上

### copier のインストール

```bash
pipx install copier
# または
pip install copier
```

### 実行方法

```bash
copier copy gh:Javakky/claude-starter .
```

対話形式で以下の質問に回答します。

| 質問 | 説明 | デフォルト |
|---|---|---|
| `ref` | GitHub Actions で参照するバージョン | `@master` |
| `install_claude` | `.claude/` と Claude workflows をインストール | `true` |
| `install_codex` | Codex workflows をインストール | `true` |
| `install_workflows` | GitHub Workflows をインストール | `true` |
| `install_docs` | `docs/agent/` をインストール | `true` |
| `install_scripts` | `scripts/` をインストール | `true` |

### インストールオプション

```bash
# デフォルト値で対話なしインストール
copier copy gh:Javakky/claude-starter . --defaults

# 特定バージョン（タグ）を指定
copier copy gh:Javakky/claude-starter --vcs-ref v1.0.0 .

# Workflows をスキップ
copier copy gh:Javakky/claude-starter . -d install_workflows=false

# Claude 系をスキップ
copier copy gh:Javakky/claude-starter . -d install_claude=false

# Codex 系をスキップ
copier copy gh:Javakky/claude-starter . -d install_codex=false
```

### 生成される主なファイル

```text
your-project/
├── .claude/
├── .github/workflows/
│   ├── claude.yml
│   ├── claude-review.yml
│   ├── claude-plan.yml
│   ├── claude-breakdown.yml
│   ├── claude-milestone.yml
│   ├── codex.yml
│   ├── codex-review.yml
│   ├── codex-plan.yml
│   ├── codex-breakdown.yml
│   ├── codex-milestone.yml
│   └── sync_templates.yml
├── docs/agent/
├── scripts/sync_templates.py
├── CLAUDE.md
└── .copier-answers.yml
```

## 必須設定

### Claude を使う場合

1. GitHub App: [Claude App](https://github.com/apps/claude) をインストール
2. Secrets に `CLAUDE_CODE_OAUTH_TOKEN` を登録

### Codex を使う場合

1. Secrets に `OPENAI_API_KEY` を登録
2. Azure OpenAI 利用時は `AZURE_OPENAI_API_KEY` も利用可能
3. カスタム Responses endpoint 利用時は Variables に `RESPONSES_API_ENDPOINT` を登録

## ワークフローのカスタマイズ

`claude.yml` / `codex.yml` には、依存関係セットアップ用のコメントブロックがあります。  
プロジェクトに合わせて `actions/setup-node` や `npm install` などを追加してください。

## Composite Actions の概要

### Claude 系

- `prepare-claude-context`
- `run-claude`
- `run-claude-review`
- `run-claude-plan`
- `run-claude-breakdown`
- `cancel-claude-runs`

### Codex 系

- `prepare-codex-context`
- `run-codex`
- `run-codex-review`
- `run-codex-plan`
- `run-codex-breakdown`
- `cancel-codex-runs`

## プロンプトのカスタマイズ

`run-*-plan` / `run-*-breakdown` は `docs/agent/` のプロンプトを参照します。

| ファイル | 説明 |
|---|---|
| `docs/agent/PLAN_PROMPT.md` | plan 用プロンプト |
| `docs/agent/BREAKDOWN_PROMPT.md` | breakdown 用プロンプト |

### プレースホルダー

| プレースホルダー | 説明 |
|---|---|
| `{{ISSUE_NUMBER}}` | 対象 Issue 番号 |
| `{{MILESTONE_TITLE}}` | Milestone タイトル（breakdown のみ） |
