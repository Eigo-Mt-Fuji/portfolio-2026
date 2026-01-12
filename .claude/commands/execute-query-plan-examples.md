# Execute Query Plan Command - Usage Examples

This document provides practical examples of using the `/execute-query-plan` command.

## Basic Workflow

### Step 1: Design Query with @query-designer

```
@query-designer Design SQL query to get top 10 best-selling products in the last 30 days
```

The skill will generate an optimized query like:

```sql
SELECT 
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.quantity * oi.unit_price) AS total_sales
FROM 
    products p
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    INNER JOIN orders o ON oi.order_id = o.order_id
WHERE 
    o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 
    p.product_id, p.product_name
ORDER BY 
    total_sales DESC
LIMIT 10;
```

### Step 2: Generate Execution Plan

```
/execute-query-plan
```

The command will ask you questions:

```
【質問 1/5】実行するSQLクエリを教えてください。
```

Paste the query from @query-designer.

```
【質問 2/5】クエリの目的を簡潔に教えてください。
```

Answer: "過去30日の売上トップ10商品"

```
【質問 3/5】対象環境を教えてください (dev/staging/production)
```

Answer: "production"

```
【質問 4/5】データベースの種類を教えてください
```

Answer: "PostgreSQL"

```
【質問 5/5】データベースのバージョンを教えてください
```

Answer: "15"

### Step 3: Review Generated Files

The command creates 3 files in `queries/`:

```
queries/
├── 2026-01-12_top-10-products-last-30-days.sql
├── 2026-01-12_top-10-products-last-30-days.explain.sql
└── 2026-01-12_top-10-products-last-30-days_execution-guide.md
```

### Step 4: Follow Execution Guide

Open the execution guide and follow the steps:

1. **Run EXPLAIN** to check performance
2. **Review execution plan** for issues
3. **Execute main query** if plan looks good
4. **Save results** to file
5. **Record execution** in log

---

## Example 1: Development Environment Query

### Scenario
Quick data check in development database.

### Command Execution

```
/execute-query-plan
```

**Answers**:
- Query: `SELECT COUNT(*) FROM users WHERE created_at >= '2024-01-01'`
- Purpose: "2024年以降のユーザー数確認"
- Environment: "dev"
- Database: "PostgreSQL"
- Version: "15"

### Generated Files

**queries/2026-01-12_user-count-2024.sql**:
```sql
-- Query Purpose: 2024年以降のユーザー数確認
-- Created: 2026-01-12 17:30:00
-- Environment: dev
-- Database: PostgreSQL 15

SELECT COUNT(*) 
FROM users 
WHERE created_at >= '2024-01-01';
```

**queries/2026-01-12_user-count-2024.explain.sql**:
```sql
-- EXPLAIN Query for: user-count-2024
-- Run this BEFORE executing the main query

EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT COUNT(*) 
FROM users 
WHERE created_at >= '2024-01-01';
```

### Execution

```bash
# 1. Run EXPLAIN
psql -h localhost -U dev_user -d dev_db < queries/2026-01-12_user-count-2024.explain.sql

# 2. Run main query
psql -h localhost -U dev_user -d dev_db < queries/2026-01-12_user-count-2024.sql
```

---

## Example 2: Production Environment Query

### Scenario
Generate monthly revenue report for stakeholders.

### Command Execution

```
/execute-query-plan
```

**Answers**:
- Query: Complex aggregation query from @query-designer
- Purpose: "月次売上レポート生成"
- Environment: "production"
- Database: "MySQL"
- Version: "8.0"

### Generated Execution Guide Highlights

The execution guide includes extra safety checks for production:

```markdown
> [!CAUTION]
> **本番環境での実行**
> 
> - [ ] ステージング環境で事前にテスト済み
> - [ ] EXPLAIN実行計画を確認済み
> - [ ] ピーク時間帯を避けている
> - [ ] DBAまたはチームリーダーの承認を得ている
```

### Execution

```bash
# 1. Run EXPLAIN (mandatory for production)
mysql -h prod-db.example.com -u readonly_user -p prod_db < queries/2026-01-12_monthly-revenue-report.explain.sql

# 2. Review execution plan
# Check for full table scans, missing indexes, etc.

# 3. Get approval from team lead

# 4. Run main query with timeout
mysql -h prod-db.example.com -u readonly_user -p --max_execution_time=30000 prod_db < queries/2026-01-12_monthly-revenue-report.sql > results/2026-01-12_monthly-revenue-report.csv

# 5. Record execution
echo "[$(date)] Executed monthly-revenue-report - $(wc -l < results/2026-01-12_monthly-revenue-report.csv) rows" >> results/execution.log
```

---

## Example 3: SQLite Local Database

### Scenario
Query local SQLite database for analysis.

### Command Execution

```
/execute-query-plan
```

**Answers**:
- Query: `SELECT * FROM transactions WHERE amount > 1000 ORDER BY created_at DESC LIMIT 100`
- Purpose: "高額取引の確認"
- Environment: "dev"
- Database: "SQLite"
- Version: "3.40"

### Generated Files

**EXPLAIN query adapted for SQLite**:
```sql
-- EXPLAIN Query for: high-value-transactions
-- Run this BEFORE executing the main query

EXPLAIN QUERY PLAN
SELECT * FROM transactions 
WHERE amount > 1000 
ORDER BY created_at DESC 
LIMIT 100;
```

### Execution

```bash
# 1. Run EXPLAIN
sqlite3 database.db < queries/2026-01-12_high-value-transactions.explain.sql

# 2. Run main query
sqlite3 database.db < queries/2026-01-12_high-value-transactions.sql > results/2026-01-12_high-value-transactions.csv
```

---

## Example 4: Integration with @query-designer

### Complete Workflow

**Step 1**: Design query
```
@query-designer 

I have these tables:
- users (id, email, created_at, status)
- orders (id, user_id, total_amount, order_date)
- order_items (id, order_id, product_id, quantity, unit_price)

I want to find users who have made more than 5 orders in the last 90 days with total spending over $1000.
```

**Step 2**: Review designed query

@query-designer provides:
```sql
SELECT 
    u.id,
    u.email,
    COUNT(DISTINCT o.id) AS order_count,
    SUM(o.total_amount) AS total_spent
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id
WHERE 
    o.order_date >= CURRENT_DATE - INTERVAL '90 days'
    AND u.status = 'active'
GROUP BY u.id, u.email
HAVING 
    COUNT(DISTINCT o.id) > 5
    AND SUM(o.total_amount) > 1000
ORDER BY total_spent DESC;
```

**Step 3**: Generate execution plan
```
/execute-query-plan
```

Paste the query and answer questions.

**Step 4**: Execute safely

Follow the generated execution guide to run the query in production.

---

## Best Practices

### 1. Always Run EXPLAIN First

```bash
# ❌ Don't skip EXPLAIN
mysql -h prod-db -u user -p < queries/query.sql

# ✅ Always run EXPLAIN first
mysql -h prod-db -u user -p < queries/query.explain.sql
# Review results
mysql -h prod-db -u user -p < queries/query.sql
```

### 2. Use Timeouts in Production

```bash
# PostgreSQL
psql -h prod-db -U user -d db -c "SET statement_timeout = '30s';" -f queries/query.sql

# MySQL
mysql -h prod-db -u user -p --max_execution_time=30000 < queries/query.sql
```

### 3. Save Results with Timestamps

```bash
# Create results directory
mkdir -p results/

# Save with timestamp
mysql -h db -u user -p < queries/2026-01-12_report.sql > results/2026-01-12_report_$(date +%H%M%S).csv
```

### 4. Keep Execution Logs

```bash
# Log execution
echo "[$(date)] Executed: monthly-report, Rows: $(wc -l < results/report.csv)" >> results/execution.log
```

### 5. Test in Staging First

```bash
# 1. Test in staging
mysql -h staging-db -u user -p < queries/query.sql

# 2. Review results

# 3. Then run in production
mysql -h prod-db -u readonly_user -p < queries/query.sql
```

---

## Troubleshooting

### Issue: EXPLAIN shows full table scan

**Solution**:
1. Check if indexes exist on WHERE/JOIN columns
2. Use @query-designer to optimize query
3. Consider adding indexes (consult DBA)

### Issue: Query timeout

**Solution**:
1. Review EXPLAIN plan for inefficiencies
2. Add more restrictive WHERE conditions
3. Increase timeout (if justified)
4. Consider pagination

### Issue: Permission denied

**Solution**:
1. Verify database user has SELECT permission
2. Check table-level permissions
3. Contact DBA for access

---

## Directory Structure

Recommended project structure:

```
project/
├── queries/                    # Generated query files
│   ├── 2026-01-12_query1.sql
│   ├── 2026-01-12_query1.explain.sql
│   ├── 2026-01-12_query1_execution-guide.md
│   ├── 2026-01-13_query2.sql
│   └── ...
├── results/                    # Query results
│   ├── 2026-01-12_query1.csv
│   ├── 2026-01-13_query2.csv
│   ├── execution.log
│   └── ...
└── .claude/
    └── commands/
        └── execute-query-plan.md
```

---

## Next Steps

After mastering Pattern A (manual execution), consider:

1. **Pattern B**: CI/CD integration for scheduled queries
2. **Pattern C**: Interactive execution with step-by-step approval
3. **Custom templates**: Create organization-specific execution guides
4. **Automation**: Script common query execution workflows

---

## Related Commands and Skills

- **@query-designer**: Design optimized SQL queries
- **@database-administrator**: Database optimization and tuning
- **@performance-optimizer**: Query performance analysis

---

**Last Updated**: 2026-01-12
**Command Version**: 1.0.0
