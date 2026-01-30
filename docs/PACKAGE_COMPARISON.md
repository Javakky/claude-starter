# パッケージ提供方法の比較

Claude Starter を他のリポジトリに提供する方法の比較検討資料です。

## 検討した方法一覧

| # | 方法 | 導入方法 | 採用 |
|---|------|---------|------|
| 1 | npm パッケージ | `npm install` | ❌ |
| 2 | Composer パッケージ | `composer require` | ❌ |
| 3 | GitHub Reusable Workflows | `uses:` | ✅ |
| 4 | Git Submodule | `git submodule add` | ❌ |
| 5 | シェルスクリプト（curl） | `curl | bash` | ✅（メイン） |
| 6 | GitHub Template Repository | GitHub UI | 現状維持 |
| 7 | Homebrew | `brew install` | ❌ |
| 8 | GitHub CLI Extension | `gh extension install` | ❌ |

---

## 詳細比較

### 1. npm パッケージ

```bash
npm install @javakky/claude-starter --save-dev
npx claude-starter init
```

**メリット**
- 広く普及したエコシステム
- バージョン管理が容易（semver）
- 依存関係の自動解決
- CI/CD との相性が良い

**デメリット**
- Node.js / npm が必須
- 非 JavaScript プロジェクトには過剰
- npm レジストリへの公開・メンテナンスが必要
- postinstall スクリプトのセキュリティ懸念

**見送り理由**: 言語非依存を目指すため

---

### 2. Composer パッケージ

```bash
composer require javakky/claude-starter --dev
vendor/bin/claude-starter init
```

**メリット**
- PHP プロジェクトとの親和性
- PSR-4 オートローディング対応

**デメリット**
- PHP エコシステム限定
- Composer が必須
- 他言語では使えない

**見送り理由**: PHP 限定のため汎用性に欠ける

---

### 3. GitHub Reusable Workflows ✅

```yaml
jobs:
  claude:
    uses: Javakky/claude-starter/.github/workflows/reusable-claude.yml@main
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

**メリット**
- GitHub Actions のみで完結
- 追加の依存なし
- 常に最新を参照可能
- バージョン固定も可能（`@v1.0.0`）
- 入力パラメータでカスタマイズ可能

**デメリット**
- ワークフロー部分のみ
- `.claude/` ディレクトリはコピー不可
- GitHub Actions に依存

**採用理由**: CI 部分のみ必要なケースに最適

---

### 4. Git Submodule

```bash
git submodule add https://github.com/Javakky/claude-starter.git .claude-starter
ln -s .claude-starter/.claude .claude
```

**メリット**
- 言語非依存
- 特定バージョンに固定可能
- 更新時に差分確認が容易

**デメリット**
- サブモジュールの管理が複雑
- `git submodule update --init` が必要
- シンボリックリンクの扱いが面倒
- チームメンバー全員の理解が必要

**見送り理由**: 管理の複雑さが導入障壁になる

---

### 5. シェルスクリプト（curl）✅（メイン採用）

```bash
curl -sL https://raw.githubusercontent.com/Javakky/claude-starter/main/scripts/install.sh | bash
```

**メリット**
- 最も簡単（ワンライナー）
- 言語非依存
- 追加の依存なし（curl + bash のみ）
- バージョン指定可能
- オプションで部分インストール可能
- 更新スクリプトも提供可能

**デメリット**
- `curl | bash` のセキュリティ懸念（信頼できるソースからのみ）
- ネットワーク接続が必要
- スクリプトの検証が難しい

**採用理由**: 言語非依存・簡単・依存ゼロの要件を満たす

---

### 6. GitHub Template Repository（現状維持）

GitHub UI で「Use this template」ボタンからリポジトリを作成

**メリット**
- 最も簡単（UI のみ）
- 追加設定不要
- GitHub の標準機能

**デメリット**
- 新規リポジトリ作成時のみ
- 既存リポジトリには適用不可
- 作成後の更新が手動
- 差分の追従が困難

**現状**: 新規プロジェクト用として維持

---

### 7. Homebrew

```bash
brew tap javakky/claude-starter
brew install claude-starter
claude-starter init
```

**メリット**
- macOS / Linux ユーザーには馴染み深い
- グローバルインストール可能

**デメリット**
- Homebrew が必須
- CI 環境での利用が面倒
- Tap のメンテナンスが必要
- Windows 非対応

**見送り理由**: プラットフォーム依存・CI との相性が悪い

---

### 8. GitHub CLI Extension

```bash
gh extension install javakky/claude-starter
gh claude-starter init
```

**メリット**
- GitHub ユーザーには便利
- gh CLI の拡張として自然

**デメリット**
- gh CLI が必須
- 普及率が低い
- CI での利用が複雑

**見送り理由**: gh CLI が必須条件になるため

---

## 採用方針

### メイン: シェルスクリプト

- 言語非依存
- 依存ゼロ
- 簡単に使える
- バージョン管理可能

### 補助: Reusable Workflows

- CI 部分のみ必要な場合
- 既存の `.claude/` 設定を維持したい場合

### 維持: Template Repository

- 新規プロジェクト開始時の選択肢として

---

## 将来の検討事項

1. **npm パッケージ**: JavaScript/TypeScript プロジェクトが多い場合
2. **Docker イメージ**: コンテナ化が必要な場合
3. **GitHub App**: より高度な統合が必要な場合
