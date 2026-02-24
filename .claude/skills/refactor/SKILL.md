---
name: refactor
description: コードの内部構造を改善します。可読性向上、重複排除、複雑度低減、技術的負債の解消を依頼されたときに使用
---

# refactor

動作を変えずにコードの内部構造を改善する。

## 原則

**Read before editing**: コードを読む前にリファクタしない。

**テストがない状態でリファクタしない**: 先にテストを追加。

**外部検証器を根拠に**: lint エラー、型エラー、カバレッジ、計測結果。

## リファクタの種類

### 可読性の改善
```typescript
// Before
const d = new Date();
const arr = users.filter(u => u.a);

// After
const currentDate = new Date();
const activeUsers = users.filter(user => user.isActive);
```

### 重複の排除
```typescript
// Before
const userA = await fetch('/users/a').then(r => r.json());
const userB = await fetch('/users/b').then(r => r.json());

// After
const fetchUser = (id) => fetch(`/users/${id}`).then(r => r.json());
```

### 複雑度の低減
```typescript
// Before: ネストが深い
if (data) {
  if (data.valid) {
    if (data.items.length > 0) { /* 処理 */ }
  }
}

// After: ガード節で早期リターン
if (!data) return;
if (!data.valid) return;
if (data.items.length === 0) return;
// 処理
```

## ワークフロー

1. 現状把握: 対象、問題点、改善目標
2. テスト確認: なければ先に追加
3. 小さなステップ: 1変更 → テスト → コミット
4. 検証: `npm test && npm run lint`

## このスキルでできないこと
- 動作を変える変更（機能変更は `/implement` を使用）
- 新機能の追加（`/implement` を使用）
