---
name: test-generate
description: テストコードを生成します。単体テスト、統合テスト、E2Eテストの作成、テストカバレッジの向上を依頼されたときに使用
---

# test-generate

テスト対象のコードを理解し、適切なテストを生成する。

## 原則

**Read before writing**: テスト対象のコードを読まずにテストを書かない。

**テストの三原則**:
1. 正常系: 期待通りの入力→期待通りの出力
2. 異常系: エラー入力→エラーハンドリング
3. 境界値: 空、null、最大値、最小値

## テストの種類

### 単体テスト
```typescript
describe('add', () => {
  it('正の数同士の加算', () => {
    expect(add(1, 2)).toBe(3);
  });
  it('0との加算', () => {
    expect(add(0, 5)).toBe(5);
  });
  it('無効な入力でエラー', () => {
    expect(() => add('a', 1)).toThrow();
  });
});
```

### 統合テスト
```typescript
describe('UserService', () => {
  beforeEach(async () => { await db.clear(); });
  it('ユーザーを作成して取得', async () => {
    const created = await userService.create({ name: 'Test' });
    const found = await userService.findById(created.id);
    expect(found.name).toBe('Test');
  });
});
```

### E2E テスト
```typescript
test('ログインしてダッシュボード表示', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[name=email]', 'test@example.com');
  await page.fill('[name=password]', 'password');
  await page.click('button[type=submit]');
  await expect(page).toHaveURL('/dashboard');
});
```

## テストケース設計

| 種類 | 例 |
|------|---|
| 正常系 | 典型的な入力 |
| 異常系 | null、不正形式 |
| 境界値 | 空配列、最大値、1件 |

## モックの使い方

**使うべき場合**: 外部 API、DB、日時、乱数、ファイルシステム

**使うべきでない場合**: テスト対象の内部実装、単純なユーティリティ

## このスキルでできないこと
- バグの修正（`/debug` → `/implement` を使用）
- リファクタリング（`/refactor` を使用）
