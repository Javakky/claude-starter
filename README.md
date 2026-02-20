# 🤖 Claude Starter

**Claude Starter** は、AI駆動の開発ワークフローをあなたのリポジトリに数分で導入できるスターターキットです。
GitHub Actions と Claude Code を組み合わせ、Issue や Pull Request をトリガーとした「自律的なコード生成」や「自動コードレビュー」の環境を構築します。

## ✨ 特徴

*   ⚡ **簡単導入**: ワンライナーでセットアップ完了。
*   🤖 **自律的なタスク実行**: 企画 → タスク分解 → 実装 → レビュー までをAIがサポート。
*   🎨 **柔軟なカスタマイズ**: プロジェクト固有のルールやコーディング規約をAIに学習させることが可能。
*   🌐 **言語・フレームワーク不問**: どのようなプロジェクトでも利用可能。

---

## 🚀 クイックスタート

以下のコマンドを実行するだけで、必要な設定ファイル一式がリポジトリに配置されます。

```bash
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash
```

> 🔄 **Update**: 既に導入済みで最新版に更新したい場合は、`-f` オプションを使用してください。
> ```bash
> curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash -s -- -f
> ```

---

## 🔑 セットアップ

利用には **Claude App** の導入と **Claude Code OAuth Token** が必要です。

### 1️⃣ GitHub App の導入
GitHub 上で **[Claude App](https://github.com/apps/claude)** をリポジトリに追加してください。これを行わないと、Claude が Issue や PR に反応できません。

### 2️⃣ トークンの取得
ターミナルで以下のコマンドを実行し、ブラウザ認証を行ってください。
```bash
claude login
```
※ 未インストールの場合は `npm install -g @anthropic-ai/claude-code` でインストールしてください。

### 3️⃣ GitHub Secrets への登録
リポジトリの `Settings` > `Secrets and variables` > `Actions` にて、以下のシークレットを登録します。
*   **Name**: `CLAUDE_CODE_OAUTH_TOKEN`
*   **Value**: 手順2で取得したトークン

---

## 🌊 開発ワークフロー

導入後は、以下のようなサイクルでAIと協働開発を進めることができます。

### 💡 1. 企画 & 設計 (`[plan]`)
1.  GitHub で **Milestone** を作成します。
2.  自動作成される `[Milestone] <タイトル> - タスク分解` という Issue を開きます。
3.  コメントで作りたい機能を伝えます。
    > `@claude [plan] ユーザーログイン機能を実装したい。JWT認証を使って、セキュアに保ちたい。`
4.  Claude が解決策や設計プランを提案します。

### 🧩 2. タスク分解 (`[breakdown]`)
1.  プランに合意したら、タスク分解を指示します。
    > `@claude [breakdown]`
2.  Claude がプランを元にタスクを細分化し、**実装用の Issue を複数自動作成**します。

### 🏗️ 3. 実装 (`@claude`)
1.  作成された各 Issue で実装を指示します。
    > `@claude`
2.  **自動でブランチが作成**され、Claude がコードを実装・コミットします。
3.  完了後、Claude のコメントに **Create PR** のリンクが表示されます。

### 🔍 4. レビュー & ブラッシュアップ
1.  リンクから Pull Request を作成します。
2.  PR 作成をトリガーに、**自動レビュー**が走ります。
3.  必要に応じて修正指示や再レビューを依頼します。
    *   🛠️ 修正指示: `@claude <修正内容>`
    *   🔄 再レビュー: `@claude [review]`

---

## ⚙️ カスタマイズ (.claude/)

`.claude/` ディレクトリ内のファイルを編集することで、AIの挙動を制御できます。

| ディレクトリ | 説明 |
| :--- | :--- |
| 📂 **`.claude/rules/`** | プロジェクト固有のルール（コーディング規約、設計指針など）を記述します。AIはこれを参照してコードを書きます。 |
| 📂 **`.claude/commands/`** | 各コマンド実行時の追加プロンプトなどを記述します。 |

詳細な構成については [**インストールガイド (docs/INSTALLATION.md)**](docs/INSTALLATION.md) を参照してください。

## 💬 コマンドオプション

コメント内で以下のキーワードを使用することで、挙動を微調整できます。

| オプション | 説明 | 例 |
| :--- | :--- | :--- |
| ⏳ `[turns=N]` | 最大ターン数を指定（デフォルトはワークフロー設定依存） | `[turns=30]` |
| 🧠 `[opus]` / `[sonnet]` | 使用するモデルを指定 | `@claude [sonnet] リファクタリングして` |

> ⚠️ **Note**: モデル指定オプションは、自動レビュー機能では使用できません。

---

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE.md) の下で公開されています。
