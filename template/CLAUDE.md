# Claude Code ガイド

## 言語

全ての成果物（コメント、コミットメッセージ、PR説明、Issue）は日本語で生成する。

## ルール

ルール正本: `.claude/rules/`（ここだけ育てる）

## テンプレ

- タスク: `docs/agent/TASK.md`
- PR本文: `docs/agent/PR.md`

## Conventional Commits

コミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/) に従う。

レビュースキップ対象（PR タイトルのプレフィックス）:
- `docs:` / `style:` / `chore:` / `wip:`

`build:` や `ci:` はプロジェクト安定性に影響するためレビュー対象。
