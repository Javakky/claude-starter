# Claude Starter

**Claude Starter** は、AIによる開発支援 (`claude-code-action`) を、あなたのリポジトリに数分で導入するためのスターターキットです。言語やフレームワークを問わず、IssueコメントやPull Requestをトリガーとしたコード生成・自動レビューの環境を簡単に構築できます。

## 主な機能

-   **🚀 簡単な導入**: `curl | bash` のワンライナーで、必要な設定ファイル一式をリポジトリに自動で配置します。
-   **💬 コメントベースのタスク実行**: `@claude implement ...` のようにIssueやPRでコメントするだけで、機能実装、リファクタリング、CIの修正などをAIに依頼できます。
-   **🤖 PRの自動レビュー**: Pull Requestが作成・更新されると、Claudeが自動でコードをレビューし、コメントします。
-   **🧠 インテリジェントな重複実行防止**: ユーザーが指示を修正した場合（例: コメントの追加）、実行中の古いタスクを自動でキャンセルし、常に最新の指示を優先します。
-   **🔧 高いカスタマイズ性**: `.claude/` ディレクトリ内のファイルを編集するだけで、AIの振る舞いやコーディング規約、レビューの観点をプロジェクトに合わせて柔軟に調整できます。
-   **🔄 簡単な更新**: 導入後も、`update.sh` スクリプトを実行するだけで、`claude-starter` の設定を簡単に最新版へ更新できます。

## クイックスタート

### 1. インストール

お使いのリポジトリのルートディレクトリで、以下のコマンドを実行します。

```bash
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash
```
> ⚠️ **セキュリティ**: `curl | bash` を実行する前に、[スクリプトの内容](https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh)を確認することを推奨します。

### 2. シークレットの設定

リポジトリの `Settings` > `Secrets and variables` > `Actions` に移動し、以下のシークレットを登録します。

-   **Name**: `CLAUDE_CODE_OAUTH_TOKEN`
-   **Value**: あなたの Claude Code OAuth トークン

### 3. 試してみる

Issueを作成し、`@claude こんにちは！` とコメントして、Claudeが応答するか確認してみましょう。

---

より詳細な設定やカスタマイズ方法については、[**インストールガイド (INSTALLATION.md)**](docs/INSTALLATION.md) を参照してください。

## ライセンス

このプロジェクトは [MIT License](LICENSE.md) の下で公開されています。
