# Claude Code ガイド（入口）

このリポジトリで Claude Code を使うときの入口です。
ルールの正本は `.claude/rules/` にあります（ここだけ育てる）。

## 最低限
- 余計な整形・無関係なリネームはしない
- 2回続けて詰まったら止めて状況整理（ログ要点・仮説・次の一手）
- 推論する際は英語を用いてもよいが、最終的な回答は日本語で行う

## テンプレ
- タスク: `docs/agent/TASK.md`
- PR本文: `docs/agent/PR.md`

## よく使うコマンド
- 分解: `/project:orchestrator`
- 実装: `/project:implement`
- CI修正: `/project:fix_ci`
