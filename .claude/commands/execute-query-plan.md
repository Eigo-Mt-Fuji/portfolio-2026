# Execute Query Plan Command

Generate safe SQL query execution plans for manual execution.

---

## Instructions for Claude

You are executing the `/execute-query-plan` command to generate a safe SQL query execution plan.

### What is Execute Query Plan?

This command creates a **safe execution workflow** for SQL queries designed by `@query-designer` skill. It generates:

1. **Main Query File** - The SQL query to execute
2. **EXPLAIN Query File** - Performance validation query
3. **Execution Guide** - Step-by-step manual execution instructions

**Safety Philosophy**: This command NEVER executes queries automatically. It generates plans for human review and manual execution.

---

## Your Task

### Step 0: Extract Metadata from Query (if available)

**CRITICAL: Check for @query-metadata comments first**

Before asking questions, check if the query contains `@query-metadata` comments:

```sql
-- @query-metadata
-- purpose: 過去30日間の売上トップ10商品
-- database: PostgreSQL 15
-- environment: production
-- created_by: @query-designer
-- created_at: 2026-01-12 18:00:00
```

**If metadata found**:
1. Extract all metadata fields
2. Skip corresponding questions
3. Only ask for missing information

**If no metadata found**:
1. Proceed with Step 1 (ask all questions)

### Step 1: Collect Query Information

Ask the user for the following information **one question at a time**:

**IMPORTANT**: Skip questions if metadata was already extracted in Step 0.

```
こんにちは！SQLクエリ実行計画を生成します。
いくつか質問させてください。

【質問 1/N】実行するSQLクエリを教えてください。
@query-designerで設計したクエリをそのまま貼り付けてください。

👤 ユーザー: [回答待ち]
```

**Questions to ask (one at a time, skip if metadata exists)**:

1. **SQL Query**: The query to execute (from @query-designer or user-provided)
2. **Query Purpose**: Brief description (skip if `purpose` in metadata)
3. **Target Environment**: dev, staging, or production (skip if `environment` in metadata)
4. **Database Type**: PostgreSQL, MySQL, SQLite, SQL Server (skip if `database` in metadata)
5. **Database Version**: e.g., PostgreSQL 15, MySQL 8.0 (skip if `database` in metadata)

### Step 2: Validate Query Safety

Before generating files, perform safety checks:

**Safety Checks**:
- ✅ Query is SELECT only (read-only)
- ✅ No UPDATE, DELETE, INSERT, DROP, TRUNCATE
- ✅ No transaction control (COMMIT, ROLLBACK)
- ✅ No DDL statements (CREATE, ALTER)

**If unsafe query detected**:
```
⚠️ 警告: このクエリには更新操作が含まれています。

このコマンドは参照クエリ（SELECT）専用です。
更新操作には別のワークフローが必要です。

検出された操作: [UPDATE/DELETE/etc.]

続行しますか？（推奨: いいえ）
👤 ユーザー: [回答待ち]
```

### Step 3: Generate Query Name

Create a descriptive query name from the purpose:

**Naming Rules**:
- Lowercase with hyphens
- Max 50 characters
- Descriptive and searchable
- No special characters except hyphens

**Examples**:
- "売上トップ10商品の取得" → `top-10-products-by-sales`
- "過去30日のユーザー登録数" → `user-registrations-last-30-days`
- "月次売上レポート" → `monthly-revenue-report`

### Step 4: Generate EXPLAIN Query

Create dialect-specific EXPLAIN query:

#### PostgreSQL
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
[ORIGINAL QUERY];
```

#### MySQL
```sql
EXPLAIN FORMAT=JSON
[ORIGINAL QUERY];
```

#### SQLite
```sql
EXPLAIN QUERY PLAN
[ORIGINAL QUERY];
```

#### SQL Server
```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
[ORIGINAL QUERY];
```

### Step 5: Generate Execution Guide

Create a comprehensive markdown guide with the following structure:

```markdown
# クエリ実行ガイド - [Query Purpose]

## 📋 クエリ情報

- **クエリ名**: [query-name]
- **作成日時**: [YYYY-MM-DD HH:MM]
- **作成者**: [User name or "Claude Code"]
- **対象環境**: [dev/staging/production]
- **データベース**: [Database Type Version]
- **目的**: [Query Purpose]

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

---

## 🔍 ステップ1: EXPLAIN実行（必須）

### 実行コマンド

\`\`\`bash
# ファイルから実行
[database-specific command] < queries/[timestamp]_[query-name].explain.sql

# または直接実行
[database-specific command]
\`\`\`

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

\`\`\`
[Database-specific EXPLAIN output example]
\`\`\`

**判断**:
- ✅ 問題なし → ステップ2へ進む
- ❌ 問題あり → クエリを修正するか、DBAに相談

---

## 🚀 ステップ2: クエリ実行

### 実行前チェックリスト

- [ ] EXPLAIN実行計画を確認済み
- [ ] 実行時間が許容範囲内と判断
- [ ] 本番環境の場合、ピーク時間を避けている
- [ ] 結果の保存先を決定済み

### 実行コマンド

\`\`\`bash
# 結果をCSVファイルに保存
[database-specific command] < queries/[timestamp]_[query-name].sql > results/[timestamp]_[query-name].csv

# または画面に表示
[database-specific command] < queries/[timestamp]_[query-name].sql
\`\`\`

### タイムアウト設定（推奨）

\`\`\`bash
# PostgreSQL
psql -h [host] -U [user] -d [database] -c "SET statement_timeout = '30s';" -f queries/[timestamp]_[query-name].sql

# MySQL
mysql -h [host] -u [user] -p --max_execution_time=30000 < queries/[timestamp]_[query-name].sql
\`\`\`

---

## 📊 ステップ3: 結果の検証

### 結果確認

- [ ] 取得行数が想定範囲内
- [ ] データの内容が正しい
- [ ] NULL値の扱いが適切
- [ ] 重複データがない（意図しない場合）

### 結果の保存

\`\`\`bash
# 結果ディレクトリの作成
mkdir -p results/

# 実行ログの記録
echo "[$(date)] Executed [query-name] - [row count] rows" >> results/execution.log
\`\`\`

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
- 他のクエリと競合

**対処**:
1. EXPLAINで実行計画を再確認
2. インデックスの追加を検討
3. クエリの条件を絞る
4. 実行時間帯を変更

### 問題: 接続エラー

**原因**:
- 接続情報が間違っている
- ネットワークの問題
- データベースがダウン

**対処**:
1. 接続情報を確認
2. ネットワーク接続を確認
3. データベースの状態を確認

### 問題: 権限エラー

**原因**:
- 読み取り権限がない
- テーブルへのアクセス権限がない

**対処**:
1. DBAに権限を確認
2. 適切な権限を付与してもらう

---

## 📝 実行記録テンプレート

実行後、以下の情報を記録してください:

\`\`\`
実行日時: [YYYY-MM-DD HH:MM:SS]
実行者: [Your Name]
環境: [dev/staging/production]
クエリ名: [query-name]
実行時間: [X seconds]
取得行数: [N rows]
結果ファイル: results/[timestamp]_[query-name].csv
備考: [Any notes]
\`\`\`

---

## 🔗 関連ファイル

- **メインクエリ**: `queries/[timestamp]_[query-name].sql`
- **EXPLAINクエリ**: `queries/[timestamp]_[query-name].explain.sql`
- **実行ガイド**: `queries/[timestamp]_[query-name]_execution-guide.md` (このファイル)

---

**生成日時**: [YYYY-MM-DD HH:MM:SS]
**生成ツール**: Claude Code - execute-query-plan command
```

### Step 6: Generate Database-Specific Commands

Include environment-specific connection commands in the guide:

#### PostgreSQL
```bash
# Development
psql -h localhost -U dev_user -d dev_db

# Production (read-only)
psql -h prod-db.example.com -U readonly_user -d prod_db
```

#### MySQL
```bash
# Development
mysql -h localhost -u dev_user -p dev_db

# Production (read-only)
mysql -h prod-db.example.com -u readonly_user -p prod_db
```

#### SQLite
```bash
# Local file
sqlite3 database.db
```

#### SQL Server
```bash
# Using sqlcmd
sqlcmd -S server_name -U user_name -P password -d database_name
```

### Step 7: Save Files

Create the `queries/` directory if it doesn't exist, then save three files:

**File 1**: `queries/{YYYY-MM-DD}_{query-name}.sql`
```sql
-- Query Purpose: [purpose]
-- Created: [timestamp]
-- Environment: [environment]
-- Database: [database type version]

[ORIGINAL QUERY]
```

**File 2**: `queries/{YYYY-MM-DD}_{query-name}.explain.sql`
```sql
-- EXPLAIN Query for: [query-name]
-- Run this BEFORE executing the main query

[DIALECT-SPECIFIC EXPLAIN QUERY]
```

**File 3**: `queries/{YYYY-MM-DD}_{query-name}_execution-guide.md`
```markdown
[FULL EXECUTION GUIDE AS GENERATED IN STEP 5]
```

### Step 8: Present Summary

After saving files, present a summary:

```markdown
## ✅ クエリ実行計画の生成完了

### 📁 生成されたファイル

1. **メインクエリ**: `queries/[timestamp]_[query-name].sql`
2. **EXPLAINクエリ**: `queries/[timestamp]_[query-name].explain.sql`
3. **実行ガイド**: `queries/[timestamp]_[query-name]_execution-guide.md`

### 🎯 次のステップ

1. **実行ガイドを確認**: `queries/[timestamp]_[query-name]_execution-guide.md` を開く
2. **EXPLAINを実行**: 実行計画を確認
3. **実行計画を評価**: 問題がないか確認
4. **メインクエリを実行**: 手順に従って実行

### ⚠️ 重要な注意事項

- 本番環境での実行前に、必ずステージング環境でテストしてください
- EXPLAINの実行は必須です
- ピーク時間帯の実行は避けてください
- 実行結果に個人情報が含まれる場合は適切に管理してください

### 🔗 関連スキル

クエリの設計・最適化が必要な場合:
\`\`\`
@query-designer [your request]
\`\`\`
```

---

## Environment-Specific Warnings

### Production Environment

When `target_environment` is "production", add extra warnings:

```markdown
> [!CAUTION]
> **本番環境での実行**
> 
> このクエリは本番環境で実行される予定です。以下を必ず確認してください:
> 
> - [ ] ステージング環境で事前にテスト済み
> - [ ] EXPLAIN実行計画を確認済み
> - [ ] ピーク時間帯を避けている
> - [ ] DBAまたはチームリーダーの承認を得ている
> - [ ] ロールバック計画がある（該当する場合）
> - [ ] 監査ログに記録する準備ができている
```

### Development Environment

When `target_environment` is "dev", use streamlined guide:

```markdown
> [!NOTE]
> **開発環境での実行**
> 
> 開発環境では比較的自由に実行できますが、以下は確認してください:
> 
> - [ ] EXPLAINで実行計画を確認（推奨）
> - [ ] 他の開発者への影響がないか確認
```

---

## Query Type Detection

Detect query type and adjust safety level:

### SELECT (Read-Only) ✅
- Standard workflow
- EXPLAIN recommended
- Safe for production

### UPDATE/DELETE/INSERT ⚠️
- Show warning
- Require explicit confirmation
- Recommend transaction wrapper
- Add rollback instructions

### DDL (CREATE/ALTER/DROP) 🚫
- Show strong warning
- Recommend separate workflow
- Require DBA review

---

## Example Outputs

### Example 1: Simple SELECT Query

**Input**:
- Query: `SELECT * FROM products WHERE category = 'electronics' ORDER BY price DESC LIMIT 10`
- Purpose: "電子機器カテゴリの商品を価格順に取得"
- Environment: production
- Database: PostgreSQL 15

**Generated Files**:

`queries/2026-01-12_electronics-products-by-price.sql`:
```sql
-- Query Purpose: 電子機器カテゴリの商品を価格順に取得
-- Created: 2026-01-12 17:30:00
-- Environment: production
-- Database: PostgreSQL 15

SELECT * 
FROM products 
WHERE category = 'electronics' 
ORDER BY price DESC 
LIMIT 10;
```

`queries/2026-01-12_electronics-products-by-price.explain.sql`:
```sql
-- EXPLAIN Query for: electronics-products-by-price
-- Run this BEFORE executing the main query

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT * 
FROM products 
WHERE category = 'electronics' 
ORDER BY price DESC 
LIMIT 10;
```

### Example 2: Complex JOIN Query

**Input**:
- Query: Multi-table JOIN with aggregation
- Purpose: "過去30日の売上トップ10商品"
- Environment: production
- Database: MySQL 8.0

**Generated execution guide includes**:
- Detailed EXPLAIN interpretation
- Index recommendations
- Performance expectations
- Safety checklist for production

---

## Tool Usage

Use these tools:

1. **Write**: Create the 3 output files
2. **Bash**: Create `queries/` directory if needed
3. **AskUserQuestion**: Collect query information (one at a time)

---

## Validation

Before completing, verify:

1. **File Creation**:
   - [ ] All 3 files created
   - [ ] Files in `queries/` directory
   - [ ] Filenames follow naming convention

2. **Content Quality**:
   - [ ] EXPLAIN query is dialect-specific
   - [ ] Execution guide is comprehensive
   - [ ] Safety checks are appropriate for environment

3. **Safety**:
   - [ ] Query type detected correctly
   - [ ] Appropriate warnings included
   - [ ] Environment-specific guidance provided

---

## Next Steps After Execution

Once the command completes, users should:

1. Review the execution guide
2. Run EXPLAIN query
3. Evaluate execution plan
4. Execute main query manually
5. Record execution details

---

**Execution**: Begin query plan generation now.
