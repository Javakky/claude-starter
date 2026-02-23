# 🤖 Claude Starter

**Claude Starter** は、AI 駆動の開発ワークフローをリポジトリに数分で導入できるスターターキットです。  
GitHub Actions と AI エージェント（Claude/Codex）を組み合わせ、Issue や Pull Request をトリガーとした「自律的なコード生成」や「自動コードレビュー」の環境を構築します。

## ✨ 特徴

- ⚡ **簡単導入**: ワンライナーでセットアップ完了
- 🤖 **自律的なタスク実行**: 企画 -> タスク分解 -> 実装 -> レビュー までを AI が支援
- 🎨 **柔軟なカスタマイズ**: プロジェクト固有ルールを prompt/docs で調整可能
- 🌐 **言語・フレームワーク不問**
- 🔀 **Claude/Codex 併用対応**

---

## 🚀 クイックスタート

### 1. 前提条件

- Python 3.10 以上
- copier: `pipx install copier` または `pip install copier`

### 2. インストール

```bash
copier copy gh:Javakky/claude-starter .
```

```bash
# 特定バージョンを指定する場合
copier copy gh:Javakky/claude-starter --vcs-ref v1.0.0 .

# デフォルト設定で対話なしインストール
copier copy gh:Javakky/claude-starter . --defaults
```

---

## 🔑 セットアップ

利用する provider に応じて設定してください。

### Claude を使う場合

1. GitHub 上で **[Claude App](https://github.com/apps/claude)** をリポジトリに追加
2. `claude login` で OAuth トークンを取得
3. GitHub Secrets に `CLAUDE_CODE_OAUTH_TOKEN` を登録
4. `@claude` コメントで動作確認

### Codex を使う場合

1. GitHub Secrets に `OPENAI_API_KEY` を登録
2. Azure OpenAI を使う場合は `AZURE_OPENAI_API_KEY` も利用可能
3. カスタム Responses API エンドポイント利用時は Variables に `RESPONSES_API_ENDPOINT` を設定
4. `@codex` コメントで動作確認

### テンプレートの更新

```bash
copier update
```

詳細は [**インストールガイド (INSTALLATION.md)**](docs/INSTALLATION.md) を参照してください。

---

## 🌊 開発ワークフロー

### 💡 1. 企画 & 設計 (`[plan]`)

1. GitHub で **Milestone** を作成
2. 自動作成される `[Milestone] <タイトル> - タスク分解` Issue を開く
3. 仕様をコメントする
   - `@claude [plan] ...`
   - `@codex [plan] ...`
4. AI が設計プランを提案

### 🧩 2. タスク分解 (`[breakdown]`)

1. プラン合意後に分解を依頼
   - `@claude [breakdown]`
   - `@codex [breakdown]`
2. AI が実装可能な粒度に分解し、Issue を作成

### 🏗️ 3. 実装 (`@claude` / `@codex`)

1. 各 Issue で実装を依頼
2. AI がコード変更を実施
3. 必要に応じて PR を作成

### 🔍 4. レビュー

1. PR 作成で自動レビュー
2. 必要に応じて追記指示
   - `@claude <修正内容>` / `@codex <修正内容>`
   - `@claude [review]` / `@codex [review]`

---

## 💬 コマンドオプション

| オプション | 説明 | 例 |
| :--- | :--- | :--- |
| `[turns=N]` | 最大ターン数を指定 | `[turns=30]` |
| `[model=...]` | モデル指定（主に Codex） | `@codex [model=gpt-5-codex]` |
| `[effort=low|medium|high]` | 推論強度指定（主に Codex） | `@codex [effort=high]` |
| `[opus]` / `[sonnet]` | モデル指定（Claude） | `@claude [sonnet]` |

---

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE.md) の下で公開されています。
