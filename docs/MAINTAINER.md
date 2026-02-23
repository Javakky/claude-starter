# メンテナ向けガイド

このドキュメントは claude-starter のメンテナ向けに、copier テンプレートの管理方法を説明します。

## copier とは

[copier](https://copier.readthedocs.io/) は Python 製のプロジェクトテンプレートツールです。
Jinja2 テンプレートを使用し、対話形式でプロジェクトを生成できます。

### 主な特徴

- GitHub リポジトリから直接テンプレートを適用可能
- `copier update` でテンプレート更新を既存プロジェクトに反映可能
- 回答を `.copier-answers.yml` に保存し、更新時に再利用

---

## ディレクトリ構成

```
claude-starter/
├── copier.yml          # テンプレート設定（質問定義、除外設定）
├── template/           # テンプレート本体
│   ├── CLAUDE.md
│   ├── .claude/
│   │   ├── commands/
│   │   └── rules/
│   ├── .github/
│   │   ├── actions/
│   │   ├── workflows/
│   │   │   ├── *.yml.jinja   # Jinja2 テンプレート
│   │   │   └── *.yml         # 静的ファイル
│   │   ├── ISSUE_TEMPLATE/
│   │   └── pull_request_template.md
│   ├── docs/
│   │   └── agent/
│   └── scripts/
├── README.md
└── docs/
    ├── INSTALLATION.md
    └── MAINTAINER.md   # このファイル
```

---

## テンプレートの更新方法

### 1. 新しいファイルを追加する場合

1. `template/` 配下の適切な場所にファイルを追加
2. 変数を使用する場合は `.jinja` 拡張子を付与
3. 条件分岐が必要な場合は `copier.yml` の `_exclude` に追加

### 2. 質問を追加する場合

`copier.yml` に新しい質問を追加:

```yaml
new_question:
  type: str
  help: 質問の説明
  default: デフォルト値
  when: "{{ 条件 }}"  # オプション
```

**質問の型:**
- `str`: 文字列
- `bool`: 真偽値
- `int`: 整数
- `float`: 小数
- `yaml`: YAML形式

### 3. テンプレート変数

以下の変数がテンプレート内（`.jinja` ファイル）で使用可能:

| 変数名 | 型 | 説明 |
|--------|-----|------|
| `ref` | str | GitHub Actions 参照バージョン（例: `@master`） |
| `install_claude` | bool | `.claude/` インストール有無 |
| `install_workflows` | bool | Workflows インストール有無 |
| `install_docs` | bool | `docs/` インストール有無 |
| `install_scripts` | bool | `scripts/` インストール有無 |

### 4. `.jinja` ファイルの書き方

GitHub Actions の `${{ }}` 構文と Jinja2 の `{{ }}` 構文が衝突するため、`{% raw %}...{% endraw %}` で囲みます。

**例:**
```yaml
{% raw %}name: Claude Implement
run-name: "claude-impl issue #${{ github.event.issue.number }}"

jobs:
  impl:
    steps:
      - name: Prepare context
        uses: Javakky/claude-starter/.github/actions/prepare-claude-context{% endraw %}{{ ref }}{% raw %}
{% endraw %}
```

- `{% raw %}...{% endraw %}` 内は Jinja2 に処理されずそのまま出力
- `{{ ref }}` は Jinja2 によって置換される

---

## リリース手順

### 1. 変更を master にマージ

通常の PR フローで変更を master ブランチにマージします。

### 2. タグを作成

```bash
# セマンティックバージョニングに従う
git tag v1.0.0
git push origin v1.0.0
```

### 3. ユーザーへの案内

ユーザーは以下のコマンドで特定バージョンを使用できます:

```bash
# 新規インストール
copier copy gh:Javakky/claude-starter --vcs-ref v1.0.0 .

# 既存プロジェクトの更新
copier update --vcs-ref v1.0.0
```

---

## ローカルでのテスト

### 新規インストールのテスト

```bash
# テスト用ディレクトリを作成
mkdir /tmp/test-project && cd /tmp/test-project
git init

# ローカルパスからテンプレートを適用
copier copy /path/to/claude-starter .

# 生成されたファイルを確認
ls -la .github/workflows/
cat .github/workflows/claude.yml
```

### オプションのテスト

```bash
# Workflows なしでインストール
copier copy /path/to/claude-starter . -d install_workflows=false

# .claude/ なしでインストール
copier copy /path/to/claude-starter . -d install_claude=false
```

### 更新のテスト

```bash
# .copier-answers.yml がある状態で
copier update
```

---

## トラブルシューティング

### Q: ユーザーがカスタマイズしたファイルが上書きされる

A: `copier.yml` の `_skip_if_exists` にパターンを追加:

```yaml
_skip_if_exists:
  - ".claude/rules/*"
  - "CLAUDE.md"
```

### Q: 新しい質問を追加したが、既存ユーザーに聞かれない

A: `copier update` 時は新しい質問のみ表示されます。これは正常な動作です。デフォルト値が使用されます。

### Q: Jinja2 構文がそのまま出力される

A: 以下を確認してください:
- ファイル名が `.jinja` 拡張子で終わっているか
- `{% raw %}...{% endraw %}` が正しく閉じられているか

### Q: GitHub Actions の `${{ }}` が消える

A: `{% raw %}...{% endraw %}` で囲み忘れています。GitHub Actions の構文は必ず raw ブロック内に配置してください。

### Q: テンプレートが反映されない

A: copier のキャッシュをクリアしてみてください:

```bash
copier copy gh:Javakky/claude-starter . --trust --force
```

---

## 参考リンク

- [copier 公式ドキュメント](https://copier.readthedocs.io/)
- [copier テンプレート設定](https://copier.readthedocs.io/en/stable/configuring/)
- [Jinja2 テンプレート構文](https://jinja.palletsprojects.com/en/3.1.x/templates/)
