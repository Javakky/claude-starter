# Terraform × Cloudflare Pages セットアップガイド

このガイドでは、Terraform を使って Cloudflare Pages プロジェクトを管理する方法を、初心者向けに解説します。

## 目次

1. [前提知識](#前提知識)
2. [事前準備](#事前準備)
3. [Terraform の基本概念](#terraform-の基本概念)
4. [ファイル構成](#ファイル構成)
5. [初期セットアップ手順](#初期セットアップ手順)
6. [GitHub Actions ワークフロー](#github-actions-ワークフロー)
7. [日常の運用フロー](#日常の運用フロー)
8. [トラブルシューティング](#トラブルシューティング)

---

## 前提知識

### Terraform とは

Terraform は、インフラストラクチャをコードで管理するツール（Infrastructure as Code: IaC）です。
GUI で手動設定する代わりに、設定ファイル（`.tf`）にインフラの定義を書き、コマンドで適用します。

**メリット:**
- インフラの変更履歴を Git で追跡できる
- 環境の再現性が高い（同じコードで同じ環境を構築できる）
- レビュープロセスを通じて変更を管理できる

### Cloudflare Pages とは

Cloudflare Pages は、静的サイトや JAMstack アプリケーションをホスティングするサービスです。
GitHub リポジトリと連携し、コードの変更を自動でデプロイできます。

---

## 事前準備

### 1. Terraform のインストール

```bash
# macOS（Homebrew）
brew install terraform

# バージョン確認
terraform version
```

その他の OS は [公式インストールガイド](https://developer.hashicorp.com/terraform/install) を参照してください。

### 2. Cloudflare アカウントの準備

以下の情報を Cloudflare ダッシュボードから取得してください:

| 項目 | 取得方法 |
|---|---|
| **アカウント ID** | ダッシュボード右側のサイドバーに表示 |
| **API トークン** | 「マイプロフィール」→「API トークン」→「トークンを作成」 |

#### API トークンの作成手順

1. Cloudflare ダッシュボードで「マイプロフィール」→「API トークン」を開く
2. 「トークンを作成」をクリック
3. 「カスタムトークンを作成」を選択
4. 以下の権限を設定:
   - **アカウント** → **Cloudflare Pages** → **編集**
5. トークンを作成し、安全な場所に保存する

> ⚠️ API トークンは一度しか表示されません。必ずコピーして安全に保管してください。

### 3. Backend の選択

Terraform は「state（状態）」ファイルでインフラの現在の状態を管理します。
このファイルの保存先（backend）を選ぶ必要があります。

| Backend | 特徴 | 推奨度 |
|---|---|---|
| **Terraform Cloud** | 無料枠あり。state 管理・ロック・UI を提供 | ⭐ 推奨 |
| **S3 互換（R2 等）** | Cloudflare R2 や AWS S3 に state を保存 | ○ 中級者向け |
| **なし（ローカル）** | state がローカルにのみ保存される | × CI では使用不可 |

---

## Terraform の基本概念

### よく使うコマンド

| コマンド | 説明 |
|---|---|
| `terraform init` | プロバイダーのダウンロード・backend の初期化 |
| `terraform fmt -check` | コードのフォーマットチェック |
| `terraform validate` | 設定の構文検証 |
| `terraform plan` | 変更のプレビュー（実際には適用しない） |
| `terraform apply` | 変更の適用 |
| `terraform show` | 現在の state を確認 |

### 実行フロー

```
terraform init → terraform plan → (確認) → terraform apply
     ↓                 ↓                          ↓
 プロバイダー      変更内容を         確認後に実際に
 をダウンロード    プレビュー         インフラを変更
```

各コマンドの詳しい説明は [infra/main.tf](../../infra/main.tf) のファイル先頭コメントを参照してください。

---

## ファイル構成

```
infra/
├── main.tf        # メインの Terraform 設定（プロバイダー・リソース定義）
├── variables.tf   # 変数の定義（入力パラメータ）
└── outputs.tf     # 出力の定義（適用後に表示される情報）
```

各ファイルには詳しいコメントが記載されています。以下のリンクから直接参照できます:

- [main.tf](../../infra/main.tf) — Terraform 設定、プロバイダー（Cloudflare）、バックエンド、リソース（Pages プロジェクト）の定義。カスタマイズ例もコメントに記載。
- [variables.tf](../../infra/variables.tf) — 外部から注入する変数の定義。`sensitive = true` の説明や、変数の設定方法もコメントに記載。
- [outputs.tf](../../infra/outputs.tf) — `terraform apply` 後に表示される情報の定義。

---

## 初期セットアップ手順

### 手順 1: GitHub リポジトリに Secrets を登録

GitHub リポジトリの「Settings」→「Secrets and variables」→「Actions」で以下を登録:

#### 共通（必須）

| Secret 名 | 値 |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare の API トークン |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare のアカウント ID |

#### Terraform Cloud backend の場合

| Secret 名 | 値 |
|---|---|
| `TF_API_TOKEN` | Terraform Cloud の API トークン（[User Settings > Tokens](https://app.terraform.io/app/settings/tokens) で作成） |

#### S3 互換（R2）backend の場合

| Secret 名 | 値 |
|---|---|
| `AWS_ACCESS_KEY_ID` | R2 API トークンのアクセスキー ID |
| `AWS_SECRET_ACCESS_KEY` | R2 API トークンのシークレットアクセスキー |

### 手順 2: GitHub Environment を作成

[infra-apply ワークフロー](../../.github/workflows/infra-apply.yml) は `environment: production` の承認ゲートを使用します。

1. リポジトリの「Settings」→「Environments」を開く
2. 「New environment」で `production` を作成
3. 「Required reviewers」にチェックを入れ、承認者を追加

### 手順 3: Backend を設定

Backend の設定は [infra/main.tf](../../infra/main.tf) の `terraform` ブロック内のコメントに詳しく記載されています。

#### Terraform Cloud を使う場合

1. [Terraform Cloud](https://app.terraform.io/) でアカウントを作成
2. Organization と Workspace を作成
3. copier の質問で `terraform_backend: cloud` を選択し、organization 名と workspace 名を入力
4. Terraform Cloud の Workspace 設定で環境変数を登録:
   - `TF_VAR_cloudflare_api_token`（Sensitive にチェック）
   - `TF_VAR_cloudflare_account_id`

#### S3 互換ストレージ（R2）を使う場合

1. Cloudflare ダッシュボードで R2 バケットを作成（例: `terraform-state`）
2. R2 API トークンを作成
3. copier の質問で `terraform_backend: s3` を選択
4. [infra/main.tf](../../infra/main.tf) の backend ブロックで `endpoint` を自分のアカウント ID に変更
5. GitHub Secrets に `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` を登録

### 手順 4: ローカルで動作確認

```bash
cd infra

# 環境変数を設定
export TF_VAR_cloudflare_api_token="your-api-token"
export TF_VAR_cloudflare_account_id="your-account-id"

# 初期化
terraform init

# フォーマットチェック
terraform fmt -check

# 構文検証
terraform validate

# プレビュー（まだ適用しない）
terraform plan
```

---

## GitHub Actions ワークフロー

> **注意:** `terraform_backend: none` を選択した場合、ワークフローは生成されません。

### infra-plan（プレビュー）

[infra-plan.yml](../../.github/workflows/infra-plan.yml) — 手動実行（`workflow_dispatch`）で Terraform plan を実行します。
実際のインフラ変更は行わず、変更内容のプレビューのみ表示します。

**実行方法:**
1. GitHub の「Actions」タブを開く
2. 「Terraform Plan」ワークフローを選択
3. 「Run workflow」をクリック

plan の結果は GitHub Actions の Step Summary に表示されます。

### infra-apply（適用）

[infra-apply.yml](../../.github/workflows/infra-apply.yml) — 手動実行で plan → 承認 → apply の流れでインフラ変更を適用します。

**実行フロー:**
1. `plan` ジョブ: 変更内容をプレビューし、plan ファイルを生成
2. **承認ゲート**: `production` environment の承認者がレビュー・承認
3. `apply` ジョブ: 承認された plan を適用

```
plan ジョブ → [承認待ち] → apply ジョブ
  ↓              ↓             ↓
変更内容を     承認者が      承認された
プレビュー     内容を確認    変更を適用
```

### 共通 composite action

[setup-terraform](../../.github/actions/setup-terraform/action.yml) — 両ワークフローで共通の以下の処理をまとめています:

- Terraform のインストール（`hashicorp/setup-terraform@v3`）
- `terraform init`（初期化・backend 認証含む）
- `terraform fmt -check`（フォーマットチェック）
- `terraform validate`（構文検証）

---

## 日常の運用フロー

### インフラ変更の流れ

1. `infra/` 配下の `.tf` ファイルを編集
2. ローカルで `terraform plan` を実行して変更内容を確認
3. PR を作成してレビューを受ける
4. マージ後、GitHub Actions で `infra-plan` を実行して確認
5. `infra-apply` を実行して本番に適用

### よくある変更例

カスタムドメインの追加やビルド設定の追加など、よくあるカスタマイズ例は [infra/main.tf](../../infra/main.tf) のコメントに記載されています。

---

## トラブルシューティング

### `terraform init` が失敗する

**原因:** Backend の設定が正しくない、またはネットワークエラー。

```bash
# 詳細なログを出力
TF_LOG=DEBUG terraform init
```

### `terraform plan` で認証エラーが出る

**原因:** API トークンが無効、または権限不足。

- Cloudflare ダッシュボードでトークンの有効期限を確認
- トークンに「Cloudflare Pages - 編集」権限があることを確認
- 環境変数 `TF_VAR_cloudflare_api_token` が正しく設定されていることを確認

### state のロックエラー

**原因:** 別のプロセスが state を使用中。

```bash
# ロック状態を確認（Terraform Cloud の場合は UI で確認）
terraform force-unlock <LOCK_ID>
```

> ⚠️ `force-unlock` は他のプロセスが実行中でないことを確認してから使用してください。

### CI で state が毎回初期状態になる

**原因:** Backend が `none`（ローカル）に設定されている。

CI 環境ではジョブごとにファイルシステムがリセットされるため、backend を `cloud` または `s3` に変更してください。
`copier.yml` の `terraform_backend` を変更し、`copier update` を実行します。
