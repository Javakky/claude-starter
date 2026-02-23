# メンテナ向けガイド

このドキュメントは `claude-starter` のテンプレート保守手順を説明します。
Claude/Codex の両 provider を対象にしています。

## ディレクトリ構成

```text
claude-starter/
├── copier.yml
├── template/
│   ├── .claude/
│   ├── .github/workflows/
│   │   ├── claude*.yml(.jinja)
│   │   ├── codex*.yml(.jinja)
│   │   └── sync_templates.yml
│   ├── docs/agent/
│   └── scripts/
├── .github/actions/
│   ├── *claude*/action.yml
│   └── *codex*/action.yml
├── docs/
└── README.md
```

## copier 変数

| 変数名 | 型 | 説明 |
|---|---|---|
| `ref` | str | Actions 参照バージョン（例: `@master`） |
| `install_claude` | bool | `.claude/` と Claude workflows を導入 |
| `install_codex` | bool | Codex workflows を導入 |
| `install_workflows` | bool | workflows 一式を導入 |
| `install_docs` | bool | `docs/` を導入 |
| `install_scripts` | bool | `scripts/` を導入 |

## 更新ルール

1. Claude/Codex の片方だけに仕様変更を入れた場合は、もう片方への影響有無を必ず確認
2. provider 固有差分は workflow/action 名に閉じ込める
3. `prepare-*` の出力契約（outputs）は揃える

## `.jinja` での注意

GitHub Actions の `${{ }}` と Jinja2 の `{{ }}` が衝突するため、Actions 構文は `{% raw %}` ブロックを使ってエスケープしてください。

## ローカルテスト

```bash
# 新規生成
copier copy /path/to/claude-starter /tmp/test-project

# Claudeなし
copier copy /path/to/claude-starter /tmp/test-project -d install_claude=false

# Codexなし
copier copy /path/to/claude-starter /tmp/test-project -d install_codex=false

# 両方あり
copier copy /path/to/claude-starter /tmp/test-project -d install_claude=true -d install_codex=true
```

## リリース

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

ユーザーは次で導入/更新します。

```bash
copier copy gh:Javakky/claude-starter --vcs-ref vX.Y.Z .
copier update --vcs-ref vX.Y.Z
```
