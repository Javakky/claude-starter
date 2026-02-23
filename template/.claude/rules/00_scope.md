# 00. スコープ（触って良い / 止まる）

## 変更してよい
- アプリケーションコード
- テストコード
- ドキュメント
- 目的が説明できる小規模リファクタ

## 触る前に必ず確認（Stop）
- `.env*` / secrets / credential / token / key
- 決済・課金・認証の本番設定
- 既存 migration の書き換え
- GitHub Actions の権限を強める変更（permissions の緩和など）
- 依存関係のメジャーアップデート
