# Claude Starter

任意のリポジトリで Claude Code による自動開発・レビュー機能を簡単に導入できるセットアップツールです。言語やフレームワークに依存せず、開発ワークフローを効率化します。

## 概要

Claude Starter は、AIを活用した開発支援をあなたのリポジトリに統合するための以下の機能を提供します。

-   **インストールスクリプト**: ワンライナーで必要なファイルを簡単にセットアップ。
-   **GitHub Actions**: Issue/PR コメントへの自動応答、Pull Request の自動レビュー機能。
-   **.claude/ ディレクトリ**: Claude の振る舞いを定義するプロンプトとルール。
-   **更新スクリプト**: 導入後の設定ファイルを簡単に最新の状態に保ちます。

## クイックスタート

Claude Starter をあなたのリポジトリに導入するには、以下のコマンドを実行してください。

```bash
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh | bash
```

> ⚠️ **セキュリティに関する注意**: `curl | bash` パターンを実行する前に、必ずスクリプトの内容を確認してください。
>
> ```bash
> # スクリプトの内容を確認してから実行する方法
> curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/master/scripts/install.sh -o install.sh
> cat install.sh  # 内容を確認
> chmod +x install.sh && ./install.sh
> ```

インストール後、以下の2つの設定を行ってください。

1.  **リポジトリシークレットの設定**: GitHub リポジトリの `Settings` > `Secrets and variables` > `Actions` に `CLAUDE_CODE_OAUTH_TOKEN` を追加します。
2.  **ワークフローのカスタマイズ**: プロジェクトに合わせて `.github/workflows/claude.yml` の環境設定部分などを編集します。

詳細な手順やオプションについては、[インストールガイド](docs/INSTALLATION.md) を参照してください。

## `.github/workflows/claude.yml` のサンプル

以下は、Node.js プロジェクトで `claude.yml` を利用する際のサンプルです。インストールスクリプトによって、ユーザーの最新の指示を優先するための重複実行防止ロジックが組み込まれたワークフローが生成されます。

```yaml
name: Claude

on:
  issue_comment:
    types: [created]

permissions:
  contents: write
  pull-requests: write
  issues: write
  actions: write # 実行中のワークフローをキャンセルするために必要

jobs:
  claude:
    runs-on: ubuntu-latest
    if: contains(github.event.comment.body, '@claude')
    steps:
      # ... (競合ワークフローのハンドル処理)

      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # プロジェクトの環境設定 (例: Node.js)
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - name: Install dependencies
        run: npm install

      # Claude を実行
      - name: Run Claude
        uses: Javakky/claude-starter/.github/actions/run-claude@master
        with:
          github_token: ${{ github.token }}
          comment_body: ${{ github.event.comment.body }}
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          # 必要に応じてデフォルト値をオーバーライド
          # allowed_tools: |
          #   Bash(npm run lint)
          #   Bash(npm run test)
```

## 主な機能

-   **Issue/PR コメントでの Claude 呼び出し**: `@claude [implement]` のようにメンションすることで、機能実装、CI修正、リファクタリングなどを依頼できます。
-   **インテリジェントな重複実行防止**: 複数の指示が連続して送られた場合、古いタスクを自動でキャンセルし、常に最新の指示を優先します。
-   **Pull Request の自動レビュー**: PRが作成・更新されると、Claude が自動でコードレビューを実行します。
-   **プロンプトとルールのカスタマイズ**: `.claude/` ディレクトリ内のファイルを編集し、Claude の振る舞いをプロジェクトに合わせて調整できます。

## ドキュメント

-   [**INSTALLATION.md**](docs/INSTALLATION.md) - 詳細なインストールガイド、更新方法、各設定の解説
-   [**PACKAGE_COMPARISON.md**](docs.PACKAGE_COMPARISON.md) - シェルスクリプトと他の配布方法の比較
-   [**GITHUB_WORKFLOWS.md**](docs/GITHUB_WORKFLOWS.md) - GitHub Workflows の設定ガイド

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。
