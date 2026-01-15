# クエリ実行ガイド - 直近1ヶ月以内のユーザーの購買統計

## 📋 クエリ情報

- **クエリ名**: recent-user-purchase-stats
- **作成日時**: 2026-01-12 17:58:00
- **作成者**: Claude Code
- **対象環境**: dev
- **データベース**: MySQL 8.0
- **目的**: 最終更新日時が直近1ヶ月以内のユーザの購買統計を知りたいので、何の商品をどのくらいの金額分買ったか、総購入金額と注文回数を取得して、購入金額の多い順に並べたい

---

## ⚠️ 実行前の確認事項

### 環境確認

- [ ] 正しいデータベース環境に接続していることを確認
- [ ] 接続情報が正しいことを確認
- [ ] 読み取り専用ユーザーで接続（推奨）

### クエリレビュー

- [ ] クエリロジックを理解した
- [ ] 取得するデータの範囲を確認した
- [ ] 個人情報・機密情報の取り扱いを確認した

> [!NOTE]
> **開発環境での実行**
> 
> 開発環境では比較的自由に実行できますが、以下は確認してください:
> 
> - [ ] EXPLAINで実行計画を確認（推奨）
> - [ ] 他の開発者への影響がないか確認

---

## 🔍 ステップ1: EXPLAIN実行（推奨）

### 実行コマンド

```bash
# ファイルから実行
mysql -h localhost -u dev_user -p dev_db < queries/2026-01-12_recent-user-purchase-stats.explain.sql

# または直接実行
mysql -h localhost -u dev_user -p dev_db
```

### 確認ポイント

#### ✅ 良い実行計画
- インデックスが使用されている
- 推定行数が妥当（数千〜数万行程度）
- フルテーブルスキャンがない（または小さいテーブルのみ）
- 実行時間が許容範囲内（< 5秒推奨）

#### ❌ 問題のある実行計画
- **Full Table Scan on large tables**: 大きなテーブルでフルスキャン
- **High estimated rows**: 推定行数が数百万行以上
- **Missing indexes**: インデックスが使用されていない
- **Nested loops on large datasets**: 大量データでネストループ

### 実行計画の例

```json
{
  "query_block": {
    "select_id": 1,
    "cost_info": {
      "query_cost": "XX.XX"
    },
    "table": {
      "table_name": "users",
      "access_type": "range",
      "key": "idx_users_created_at",
      "rows_examined_per_scan": XXX
    }
  }
}
```

**判断**:
- ✅ 問題なし → ステップ2へ進む
- ❌ 問題あり → クエリを修正するか、DBAに相談

---

## 🚀 ステップ2: クエリ実行

### 実行前チェックリスト

- [ ] EXPLAIN実行計画を確認済み
- [ ] 実行時間が許容範囲内と判断
- [ ] 結果の保存先を決定済み

### 実行コマンド

```bash
# 結果をCSVファイルに保存
mysql -h localhost -u dev_user -p dev_db < queries/2026-01-12_recent-user-purchase-stats.sql > results/2026-01-12_recent-user-purchase-stats.csv

# または画面に表示
mysql -h localhost -u dev_user -p dev_db < queries/2026-01-12_recent-user-purchase-stats.sql
```

### タイムアウト設定（推奨）

```bash
# MySQL
mysql -h localhost -u dev_user -p --max_execution_time=30000 dev_db < queries/2026-01-12_recent-user-purchase-stats.sql
```

---

## 📊 ステップ3: 結果の検証

### 結果確認

- [ ] 取得行数が想定範囲内
- [ ] データの内容が正しい
- [ ] NULL値の扱いが適切
- [ ] JSON配列が正しくフォーマットされている

### 結果の保存

```bash
# 結果ディレクトリの作成
mkdir -p results/

# 実行ログの記録
echo "[$(date)] Executed recent-user-purchase-stats - $(wc -l < results/2026-01-12_recent-user-purchase-stats.csv) rows" >> results/execution.log
```

---

## 🔧 MySQL固有の注意事項

### PostgreSQL → MySQL 構文変換

このクエリは元々PostgreSQL用でしたが、MySQL 8.0用に以下の変換を行いました:

| PostgreSQL | MySQL 8.0 |
|------------|-----------|
| `INTERVAL '1 month'` | `INTERVAL 1 MONTH` |
| `CURRENT_DATE - INTERVAL '1 month'` | `DATE_SUB(CURDATE(), INTERVAL 1 MONTH)` |
| `ARRAY_AGG(...)` | `JSON_ARRAYAGG(JSON_OBJECT(...))` |

### JSON結果の解析

`purchased_products`カラムはJSON配列として返されます:

```json
[
  {
    "product_name": "Laptop",
    "quantity": 2,
    "amount": 2400.00
  },
  {
    "product_name": "Smartphone",
    "quantity": 1,
    "amount": 800.00
  }
]
```

### JSON整形表示

```bash
# JSON整形して表示
mysql -h localhost -u dev_user -p dev_db -e "
SELECT 
    user_id,
    username,
    JSON_PRETTY(purchased_products) AS products,
    total_purchase_amount,
    order_count
FROM (...);
"
```

---

## 🔒 セキュリティとコンプライアンス

### データの取り扱い

- [ ] 個人情報が含まれる場合、適切に管理
- [ ] 結果ファイルのアクセス権限を設定
- [ ] 不要になったら結果ファイルを削除

### 監査証跡

- [ ] 実行日時を記録
- [ ] 実行者を記録
- [ ] 実行目的を記録

---

## 🆘 トラブルシューティング

### 問題: クエリが遅い

**原因**:
- インデックスが使用されていない
- データ量が想定より多い
- CTEの最適化が不十分

**対処**:
1. EXPLAINで実行計画を再確認
2. 以下のインデックスが存在するか確認:
   - `users.created_at`
   - `users.status`
   - `orders.user_id`
   - `orders.status`
   - `order_items.order_id`
   - `order_items.product_id`
3. クエリの条件を絞る
4. 実行時間帯を変更

### 問題: JSON_ARRAYAGGエラー

**原因**:
- MySQL 5.7以前のバージョン（JSON関数未対応）
- データ型の不一致

**対処**:
1. MySQLバージョンを確認: `SELECT VERSION();`
2. MySQL 8.0以降であることを確認
3. データ型を確認

### 問題: 接続エラー

**原因**:
- 接続情報が間違っている
- ネットワークの問題
- データベースがダウン

**対処**:
1. 接続情報を確認
2. ネットワーク接続を確認
3. データベースの状態を確認

---

## 📝 実行記録テンプレート

実行後、以下の情報を記録してください:

```
実行日時: 2026-01-12 18:00:00
実行者: [Your Name]
環境: dev
クエリ名: recent-user-purchase-stats
実行時間: [X seconds]
取得行数: [N rows]
結果ファイル: results/2026-01-12_recent-user-purchase-stats.csv
備考: MySQL 8.0で実行、JSON_ARRAYAGG使用
```

---

## 🔗 関連ファイル

- **メインクエリ**: `queries/2026-01-12_recent-user-purchase-stats.sql`
- **EXPLAINクエリ**: `queries/2026-01-12_recent-user-purchase-stats.explain.sql`
- **実行ガイド**: `queries/2026-01-12_recent-user-purchase-stats_execution-guide.md` (このファイル)

---

**生成日時**: 2026-01-12 17:58:00
**生成ツール**: Claude Code - execute-query-plan command
