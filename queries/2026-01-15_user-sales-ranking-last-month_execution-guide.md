# クエリ実行ガイド - 先月のユーザー別売上ランキング（購入商品詳細付き）

## 📋 クエリ情報

- **クエリ名**: user-sales-ranking-last-month
- **作成日時**: 2026-01-15 20:47:48
- **作成者**: Claude Code (@query-designer)
- **対象環境**: production
- **データベース**: MySQL 8.0
- **目的**: 先月のユーザー別売上ランキング（購入商品詳細付き）

---

## ⚠️ 実行前の確認事項

### 環境確認

- [ ] 正しいデータベース環境に接続していることを確認
- [ ] 接続情報が正しいことを確認
- [ ] 読み取り専用ユーザーで接続（推奨）

### クエリレビュー

- [ ] クエリロジックを理解した
- [ ] 取得するデータの範囲: 直近1ヶ月
- [ ] 集約処理: ユーザーごとの売上合計と商品リスト
- [ ] 個人情報・機密情報の取り扱いを確認した（ユーザー名、メールアドレスが含まれます）

> [!CAUTION]
> **本番環境での実行**
> 
> このクエリは本番環境で実行される予定です。以下を必ず確認してください:
> 
> - [ ] ステージング環境で事前にテスト済み
> - [ ] EXPLAIN実行計画を確認済み
> - [ ] ピーク時間帯を避けている
> - [ ] DBAまたはチームリーダーの承認を得ている
> - [ ] 監査ログに記録する準備ができている

---

## 🔍 ステップ1: EXPLAIN実行（必須）

### 実行コマンド

```bash
# ファイルから実行
mysql -h prod-db.example.com -u readonly_user -p prod_db < queries/2026-01-15_user-sales-ranking-last-month.explain.sql
```

### 確認ポイント

#### ✅ 良い実行計画
- インデックスが使用されている（特に `orders.order_date`, `orders.status`）
- 推定行数が妥当
- `Using temporary` や `Using filesort` が許容範囲内

#### ❌ 問題のある実行計画
- **Full Table Scan**: `ALL` と表示されるテーブルがある
- **Rows Examined**: 調査行数が非常に多い
- **Nested Loop**: 効率の悪い結合

### 実行計画の例

```json
{
  "query_block": {
    "select_id": 1,
    "cost_info": { "query_cost": "..." },
    "grouping_operation": {
      "using_filesort": true,
      ...
    }
  }
}
```

**判断**:
- ✅ 問題なし → ステップ2へ進む
- ❌ 問題あり → インデックス追加を検討するか、実行を中止

---

## 🚀 ステップ2: クエリ実行

### 実行前チェックリスト

- [ ] EXPLAIN実行計画を確認済み
- [ ] 実行時間が許容範囲内と判断
- [ ] 本番環境の負荷状況を確認済み（ピーク時でない）
- [ ] 結果の保存先を決定済み

### 実行コマンド

```bash
# 結果をCSVファイルに保存（推奨）
mysql -h prod-db.example.com -u readonly_user -p prod_db < queries/2026-01-15_user-sales-ranking-last-month.sql > results/2026-01-15_user-sales-ranking-last-month.csv
```

### タイムアウト設定（推奨）

```bash
# 最大実行時間を30秒に設定
mysql -h prod-db.example.com -u readonly_user -p --max_execution_time=30000 prod_db < queries/2026-01-15_user-sales-ranking-last-month.sql > results/2026-01-15_user-sales-ranking-last-month.csv
```

---

## 📊 ステップ3: 結果の検証

### 結果確認

- [ ] データが取得できているか（ファイルサイズ確認）
- [ ] `purchased_products_list` カラムが正しくカンマ区切りになっているか
- [ ] `total_sales_amount` のソート順が正しいか

### 結果の保存

```bash
# 結果ディレクトリの作成
mkdir -p results/

# 実行ログの記録
echo "[$(date)] Executed user-sales-ranking-last-month - $(wc -l < results/2026-01-15_user-sales-ranking-last-month.csv) rows" >> results/execution.log
```

---

## 🔒 セキュリティとコンプライアンス

### データの取り扱い

- [ ] **個人情報（メール、ユーザー名）が含まれています**。結果ファイルの取り扱いには十分注意してください。
- [ ] 結果ファイルは暗号化するか、アクセス制限のある安全な場所に保存してください。
- [ ] 不要になったら確実に削除してください。

### 監査証跡

- [ ] 実行日時を記録
- [ ] 実行者を記録
- [ ] 実行目的を記録

---

## 🆘 トラブルシューティング

### 問題: クエリがタイムアウトする

**原因**:
- 対象データ量が多すぎる（1ヶ月分のデータが多い）
- インデックス不足

**対処**:
1. 対象期間を短くする（例：1週間ごと）
2. `LIMIT 100` などを追加して試す
3. 以下のインデックスを追加検討:
   ```sql
   CREATE INDEX idx_orders_date_status ON orders(order_date, status);
   ```

### 問題: GROUP_CONCATの結果が切れる

**原因**:
- `group_concat_max_len` のデフォルト制限（1024バイト）を超えている

**対処**:
- セッション変数を設定して実行:
  ```sql
  SET SESSION group_concat_max_len = 10000;
  -- その後にSELECTを実行
  ```

---

## 📝 実行記録テンプレート

実行後、以下の情報を記録してください:

```
実行日時: [YYYY-MM-DD HH:MM:SS]
実行者: [Your Name]
環境: production
クエリ名: user-sales-ranking-last-month
実行時間: [X seconds]
取得行数: [N rows]
結果ファイル: results/2026-01-15_user-sales-ranking-last-month.csv
備考: [Any notes]
```

---

## 🔗 関連ファイル

- **メインクエリ**: `queries/2026-01-15_user-sales-ranking-last-month.sql`
- **EXPLAINクエリ**: `queries/2026-01-15_user-sales-ranking-last-month.explain.sql`
- **実行ガイド**: `queries/2026-01-15_user-sales-ranking-last-month_execution-guide.md` (このファイル)

---

**生成日時**: 2026-01-15 20:47:48
**生成ツール**: Claude Code - execute-query-plan command
