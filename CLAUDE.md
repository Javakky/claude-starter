# Claude Code ガイド

## プロジェクト概要

Claude Starter は、GitHub Actions × Claude Code による AI 駆動開発ワークフローを導入する copier テンプレート。

- テンプレート本体: `template/`
- ルール正本: `.claude/rules/`（ここだけ育てる）
- テンプレ同期: `python scripts/sync_templates.py`（`docs/agent/` → `.github/` へ反映）

## 言語

全ての成果物（コメント、コミットメッセージ、PR説明、Issue）は日本語で生成する。

## 環境・検証

- `template/` 配下と本体（`.claude/rules/`、`docs/agent/`）の内容を一致させること
- テンプレ同期: `python scripts/sync_templates.py`
- copier 設定: `copier.yml`（`_skip_if_exists` でユーザーカスタマイズを保護）

## テンプレ

- タスク: `docs/agent/TASK.md`
- PR本文: `docs/agent/PR.md`

## Conventional Commits

コミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/) に従う。

レビュースキップ対象（PR タイトルのプレフィックス）:
- `docs:` / `style:` / `chore:` / `wip:`

`build:` や `ci:` はプロジェクト安定性に影響するためレビュー対象。
