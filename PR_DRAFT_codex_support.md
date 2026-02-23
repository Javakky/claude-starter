# PR下書き: claude-starter に Codex 対応を追加

## タイトル案
feat: Claude と並行して利用できる Codex ワークフロー/アクションを追加

## 概要
このPRは、既存の Claude フローを維持したまま、`claude-starter` に **Codexベースの自動化フロー**を追加します。

目的は、現在の issue/PR 駆動ワークフロー（`implement` / `review` / `plan` / `breakdown` / `milestone`）を、以下で Codex でも同等運用できるようにすることです。

- `@codex` コメントトリガー
- `openai/codex-action@v1`
- `OPENAI_API_KEY`（必要に応じて `AZURE_OPENAI_API_KEY`）

既存ユーザーへの影響を避けるため、置き換えではなく互換拡張として実装します。

## 背景
`claude-starter` には、すでに運用上有効な制御が揃っています。

- prepare-context による実行可否判定
- concurrency による重複/競合実行防止
- コメント実行者の権限チェック
- force push / commit prefix による review スキップ
- milestone 起点の plan / breakdown フロー

Codex の公式 GitHub 連携と GitHub Action が利用可能になったため、既存の設計資産を活かして provider を追加します。

## スコープ
### In scope
- Codex 用ワークフロー（template + root）の追加
  - `codex.yml`
  - `codex-review.yml`
  - `codex-plan.yml`
  - `codex-breakdown.yml`
  - `codex-milestone.yml`
- Codex 用 composite action の追加
  - `prepare-codex-context`
  - `run-codex`
  - `run-codex-review`
  - `run-codex-plan`
  - `run-codex-breakdown`
  - `cancel-codex-runs`
- 導入/運用ドキュメントの追記
- Copier の選択肢追加（Codex のインストール可否と生成物制御）

### Out of scope（後続）
- provider差異を吸収した完全自動 `Issue -> branch -> commit -> PR` フロー
- 高度なマルチエージェント並列制御

## 変更方針（ファイル単位）
### 1. Workflows
- `template/.github/workflows/` に Codex 用テンプレートを追加
- 自リポジトリ `.github/workflows/` にも dogfooding 用を追加
- 既存 Claude ワークフローは維持

### 2. Actions
- `.github/actions/` に Codex 用アクションを追加
- `prepare-claude-context` のロジックを `prepare-codex-context` へ移植
  - トリガー解析: `@codex`, `[review]`, `[plan]`, `[breakdown]`
  - 権限判定: `admin,maintain,write`
  - skip 判定と outputs 契約は Claude 版と同等
- `run-codex*` は `openai/codex-action@v1` を利用

### 3. Secret / Inputs
- Codex 用の必須設定をドキュメント化
  - `OPENAI_API_KEY`
  - 任意で `AZURE_OPENAI_API_KEY`
- Claude 利用者向け `CLAUDE_CODE_OAUTH_TOKEN` は維持

### 4. Prompt / Agent docs
- `docs/agent/` に Codex 用プロンプトを追加
- トリガー例を `@claude` だけでなく `@codex` も記載
- Provider 選択（Claudeのみ / Codexのみ / 併用）の運用指針を追加

### 5. Copier
- 選択肢追加（例）
  - `install_codex: true|false`
  - `install_claude: true|false`（既存）
- `_exclude` と生成対象マトリクスを更新

## 後方互換性
- 既存 Claude ユーザーの動作は維持
- デフォルト挙動は現行優先（必要なら `install_codex=true` で有効化）
- 両 provider 併用時は、トリガー語と concurrency 名で実行系統を分離

## セキュリティ
- workflow ごとの最小権限 `permissions` を維持
- コメント実行者の権限ゲート（`admin/maintain/write`）を維持
- fork PR の安全側スキップ方針を維持
- Codex 実行時の safety strategy を明示

## 受け入れ条件
- `@codex` で implement が起動する
- `@codex [review]` が PR 作成時/PR コメント時に動作する
- `@codex [plan]` と `@codex [breakdown]` が end-to-end で動作する
- milestone 作成時に分解用 Issue が自動作成される
- skip/permission/concurrency のポリシーが Claude 版と整合する
- INSTALLATION/README に Codex 導入手順が反映される

## テスト計画
1. テンプレート生成のスモークテスト
- `copier copy . /tmp/codex-sample -d install_workflows=true -d install_codex=true`

2. ワークフロー構文チェック
- YAML lint / action metadata チェック

3. 検証用リポジトリで E2E
- Issue コメントで `@codex`
- PR コメントで `@codex [review]`
- `@codex [plan]` -> `@codex [breakdown]`
- milestone issue 自動生成確認

4. 回帰確認
- 既存 `@claude` フローが従来通り動作

## ロールアウト
- Phase 1: review / plan / breakdown / milestone
- Phase 2: implement の安定化
- Phase 3: provider 併用ドキュメントと移行ガイド整備

## リスク
- provider 間の branch/commit 自動化挙動差
- オプション仕様差（model/effort/turns）
- デュアル対応による保守面積の増加

## チェックリスト
- [ ] `template/.github/workflows` に Codex workflows 追加
- [ ] `.github/actions` に Codex actions 追加
- [ ] `copier.yml` の選択肢更新
- [ ] `README` / `docs/INSTALLATION.md` 更新
- [ ] `docs/MAINTAINER.md` 更新
- [ ] E2E 実行ログまたはスクリーンショット添付
- [ ] Claude 既存機能の回帰なし

## レビュアー向けメモ
本PRは、既存の `claude-starter` の設計・命名・責務分離を維持し、運用コストを増やさずに Codex を追加する方針です。
