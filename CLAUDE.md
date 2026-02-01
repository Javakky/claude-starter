# Claude Code ガイド（入口）

このリポジトリで Claude Code を使うときの入口です。
ルールの正本は `.claude/rules/` にあります（ここだけ育てる）。

## 最低限
- 余計な整形・無関係なリネームはしない
- 2回続けて詰まったら止めて状況整理（ログ要点・仮説・次の一手）

## 言語: 日本語での成果物生成
- **全ての成果物は日本語で生成すること。**
- コード内のコメント、Issue、Pull Request の説明、コミットメッセージなど、Claude が生成するすべてのテキストは日本語でなければならない。
- 思考プロセス（thinking process）のログは英語でも構わないが、最終的な出力は必ず日本語にすること。

## テンプレ
- タスク: `docs/agent/TASK.md`
- PR本文: `docs/agent/PR.md`

## よく使うコマンド
- 分解: `/project:orchestrator`
- 実装: `/project:implement`
- CI修正: `/project:fix_ci`
