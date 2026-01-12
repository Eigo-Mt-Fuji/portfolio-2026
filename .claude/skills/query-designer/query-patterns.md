# Query Patterns and Anti-Patterns

This document provides common SQL query patterns, optimization techniques, and anti-patterns to avoid.

## Common Query Patterns

### 1. Pagination

#### Offset-Based Pagination

```sql
-- Simple pagination
SELECT *
FROM products
ORDER BY product_id
LIMIT 20 OFFSET 40;  -- Page 3 (20 items per page)

-- With total count
SELECT 
    COUNT(*) OVER() AS total_count,
    product_id,
    product_name,
    price
FROM products
ORDER BY product_id
LIMIT 20 OFFSET 40;
```

**Pros**: Simple to implement
**Cons**: Slow for large offsets, inconsistent results if data changes

#### Cursor-Based Pagination (Keyset Pagination)

```sql
-- First page
SELECT *
FROM products
WHERE product_id > 0
ORDER BY product_id
LIMIT 20;

-- Next page (last_id from previous page = 20)
SELECT *
FROM products
WHERE product_id > 20
ORDER BY product_id
LIMIT 20;
```

**Pros**: Consistent, fast for any page
**Cons**: Requires unique, sequential key

### 2. Upsert (Insert or Update)

#### PostgreSQL: ON CONFLICT

```sql
INSERT INTO users (user_id, username, email, updated_at)
VALUES (1, 'john_doe', 'john@example.com', NOW())
ON CONFLICT (user_id)
DO UPDATE SET
    username = EXCLUDED.username,
    email = EXCLUDED.email,
    updated_at = EXCLUDED.updated_at;
```

#### MySQL: ON DUPLICATE KEY UPDATE

```sql
INSERT INTO users (user_id, username, email, updated_at)
VALUES (1, 'john_doe', 'john@example.com', NOW())
ON DUPLICATE KEY UPDATE
    username = VALUES(username),
    email = VALUES(email),
    updated_at = VALUES(updated_at);
```

#### SQL Server: MERGE

```sql
MERGE INTO users AS target
USING (VALUES (1, 'john_doe', 'john@example.com')) AS source (user_id, username, email)
ON target.user_id = source.user_id
WHEN MATCHED THEN
    UPDATE SET username = source.username, email = source.email
WHEN NOT MATCHED THEN
    INSERT (user_id, username, email) VALUES (source.user_id, source.username, source.email);
```

### 3. Conditional Aggregation

```sql
-- Count by condition
SELECT 
    department,
    COUNT(*) AS total_employees,
    COUNT(*) FILTER (WHERE salary > 50000) AS high_earners,  -- PostgreSQL
    SUM(CASE WHEN salary > 50000 THEN 1 ELSE 0 END) AS high_earners_compat  -- All dialects
FROM employees
GROUP BY department;

-- Pivot-like aggregation
SELECT 
    product_category,
    SUM(CASE WHEN order_status = 'completed' THEN 1 ELSE 0 END) AS completed_orders,
    SUM(CASE WHEN order_status = 'pending' THEN 1 ELSE 0 END) AS pending_orders,
    SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_orders
FROM orders
GROUP BY product_category;
```

### 4. Running Totals and Moving Averages

```sql
-- Running total
SELECT 
    order_date,
    daily_sales,
    SUM(daily_sales) OVER (ORDER BY order_date) AS running_total
FROM daily_sales_summary
ORDER BY order_date;

-- Moving average (7-day)
SELECT 
    order_date,
    daily_sales,
    AVG(daily_sales) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7days
FROM daily_sales_summary
ORDER BY order_date;

-- Year-to-date total
SELECT 
    order_date,
    daily_sales,
    SUM(daily_sales) OVER (
        PARTITION BY EXTRACT(YEAR FROM order_date)
        ORDER BY order_date
    ) AS ytd_sales
FROM daily_sales_summary
ORDER BY order_date;
```

### 5. Top N per Group

#### Using Window Functions

```sql
-- Top 3 products per category
SELECT *
FROM (
    SELECT 
        category_id,
        product_name,
        price,
        ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price DESC) AS rank
    FROM products
) ranked
WHERE rank <= 3;
```

#### Using LATERAL JOIN (PostgreSQL)

```sql
SELECT 
    c.category_name,
    p.product_name,
    p.price
FROM 
    categories c
    CROSS JOIN LATERAL (
        SELECT product_name, price
        FROM products
        WHERE category_id = c.category_id
        ORDER BY price DESC
        LIMIT 3
    ) p;
```

### 6. Gap and Island Problems

#### Find Gaps in Sequence

```sql
-- Find missing IDs
SELECT 
    prev_id + 1 AS gap_start,
    next_id - 1 AS gap_end
FROM (
    SELECT 
        id AS prev_id,
        LEAD(id) OVER (ORDER BY id) AS next_id
    FROM products
) gaps
WHERE next_id - prev_id > 1;
```

#### Find Islands (Consecutive Sequences)

```sql
-- Group consecutive dates
WITH numbered AS (
    SELECT 
        order_date,
        ROW_NUMBER() OVER (ORDER BY order_date) AS rn,
        order_date - (ROW_NUMBER() OVER (ORDER BY order_date) * INTERVAL '1 day') AS grp
    FROM orders
)
SELECT 
    MIN(order_date) AS island_start,
    MAX(order_date) AS island_end,
    COUNT(*) AS consecutive_days
FROM numbered
GROUP BY grp
ORDER BY island_start;
```

### 7. Hierarchical Queries

#### Recursive CTE (Organization Chart)

```sql
WITH RECURSIVE org_tree AS (
    -- Anchor: top-level employees
    SELECT 
        employee_id,
        employee_name,
        manager_id,
        1 AS level,
        CAST(employee_name AS VARCHAR(1000)) AS path
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive: subordinates
    SELECT 
        e.employee_id,
        e.employee_name,
        e.manager_id,
        ot.level + 1,
        CAST(ot.path || ' > ' || e.employee_name AS VARCHAR(1000))
    FROM employees e
    INNER JOIN org_tree ot ON e.manager_id = ot.employee_id
)
SELECT * FROM org_tree
ORDER BY path;
```

#### Adjacency List to Nested Set

```sql
-- Find all descendants
WITH RECURSIVE descendants AS (
    SELECT employee_id
    FROM employees
    WHERE employee_id = 5  -- Starting employee
    
    UNION ALL
    
    SELECT e.employee_id
    FROM employees e
    INNER JOIN descendants d ON e.manager_id = d.employee_id
)
SELECT * FROM descendants;
```

### 8. Deduplication

#### Remove Duplicates (Keep First)

```sql
-- Using window function
DELETE FROM products
WHERE product_id IN (
    SELECT product_id
    FROM (
        SELECT 
            product_id,
            ROW_NUMBER() OVER (PARTITION BY product_name ORDER BY created_at) AS rn
        FROM products
    ) ranked
    WHERE rn > 1
);
```

#### Find Duplicates

```sql
-- Find duplicate records
SELECT 
    email,
    COUNT(*) AS duplicate_count
FROM users
GROUP BY email
HAVING COUNT(*) > 1;

-- Show all duplicate records
SELECT u.*
FROM users u
INNER JOIN (
    SELECT email
    FROM users
    GROUP BY email
    HAVING COUNT(*) > 1
) duplicates ON u.email = duplicates.email
ORDER BY u.email, u.created_at;
```

---

## Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: SELECT *

**Problem**: Retrieves unnecessary columns, wastes bandwidth and memory

```sql
-- ❌ Bad
SELECT * FROM large_table;

-- ✅ Good
SELECT id, name, email FROM large_table;
```

### ❌ Anti-Pattern 2: N+1 Queries

**Problem**: Executes one query per row, extremely slow

```sql
-- ❌ Bad (in application code)
users = db.query("SELECT * FROM users")
for user in users:
    orders = db.query(f"SELECT * FROM orders WHERE user_id = {user.id}")

-- ✅ Good (single query with JOIN)
SELECT 
    u.user_id,
    u.username,
    o.order_id,
    o.total_amount
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id;
```

### ❌ Anti-Pattern 3: Using OR in WHERE Clause

**Problem**: Prevents index usage

```sql
-- ❌ Bad
SELECT * FROM products
WHERE category = 'electronics' OR category = 'computers';

-- ✅ Good
SELECT * FROM products
WHERE category IN ('electronics', 'computers');
```

### ❌ Anti-Pattern 4: Function on Indexed Column

**Problem**: Prevents index usage

```sql
-- ❌ Bad
SELECT * FROM users
WHERE YEAR(created_at) = 2024;

-- ✅ Good
SELECT * FROM users
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
```

### ❌ Anti-Pattern 5: NOT IN with NULL Values

**Problem**: Returns unexpected results if subquery contains NULL

```sql
-- ❌ Bad (fails if subquery has NULL)
SELECT * FROM users
WHERE user_id NOT IN (SELECT user_id FROM banned_users);

-- ✅ Good
SELECT * FROM users
WHERE NOT EXISTS (
    SELECT 1 FROM banned_users WHERE banned_users.user_id = users.user_id
);

-- ✅ Alternative
SELECT u.*
FROM users u
LEFT JOIN banned_users b ON u.user_id = b.user_id
WHERE b.user_id IS NULL;
```

### ❌ Anti-Pattern 6: Implicit Type Conversion

**Problem**: Prevents index usage, slow performance

```sql
-- ❌ Bad (if user_id is INTEGER)
SELECT * FROM users WHERE user_id = '123';

-- ✅ Good
SELECT * FROM users WHERE user_id = 123;
```

### ❌ Anti-Pattern 7: Correlated Subquery in SELECT

**Problem**: Executes subquery for each row

```sql
-- ❌ Bad
SELECT 
    u.user_id,
    u.username,
    (SELECT COUNT(*) FROM orders WHERE user_id = u.user_id) AS order_count
FROM users u;

-- ✅ Good
SELECT 
    u.user_id,
    u.username,
    COALESCE(o.order_count, 0) AS order_count
FROM users u
LEFT JOIN (
    SELECT user_id, COUNT(*) AS order_count
    FROM orders
    GROUP BY user_id
) o ON u.user_id = o.user_id;
```

### ❌ Anti-Pattern 8: DISTINCT to Fix Duplicates

**Problem**: Hides underlying data quality issues

```sql
-- ❌ Bad (masks JOIN problem)
SELECT DISTINCT u.username, o.order_id
FROM users u
JOIN orders o ON u.user_id = o.user_id;

-- ✅ Good (fix the JOIN)
SELECT u.username, o.order_id
FROM users u
JOIN orders o ON u.user_id = o.user_id;
-- If duplicates exist, investigate why
```

---

## Optimization Techniques

### 1. Index Strategy

```sql
-- Single-column index
CREATE INDEX idx_users_email ON users(email);

-- Composite index (order matters!)
CREATE INDEX idx_orders_user_date ON orders(user_id, order_date);

-- Partial index (PostgreSQL)
CREATE INDEX idx_active_users ON users(email) WHERE status = 'active';

-- Covering index (include columns)
CREATE INDEX idx_products_category_covering 
ON products(category_id) INCLUDE (product_name, price);
```

### 2. Query Rewriting

#### Subquery to JOIN

```sql
-- ❌ Slower
SELECT * FROM products
WHERE category_id IN (
    SELECT category_id FROM categories WHERE is_active = true
);

-- ✅ Faster
SELECT p.*
FROM products p
INNER JOIN categories c ON p.category_id = c.category_id
WHERE c.is_active = true;
```

#### EXISTS vs IN

```sql
-- ✅ Use EXISTS for large subqueries
SELECT * FROM users u
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.user_id = u.user_id
);

-- ✅ Use IN for small, static lists
SELECT * FROM products
WHERE category_id IN (1, 2, 3);
```

### 3. Batch Operations

```sql
-- ❌ Bad: Multiple single inserts
INSERT INTO products (name, price) VALUES ('Product 1', 10.00);
INSERT INTO products (name, price) VALUES ('Product 2', 20.00);
-- ... 1000 more

-- ✅ Good: Batch insert
INSERT INTO products (name, price) VALUES
    ('Product 1', 10.00),
    ('Product 2', 20.00),
    ('Product 3', 30.00),
    -- ... up to 1000 rows
    ('Product 1000', 10000.00);
```

### 4. Materialized Views

```sql
-- Create materialized view for expensive query
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT 
    DATE(order_date) AS sale_date,
    SUM(total_amount) AS daily_sales,
    COUNT(*) AS order_count
FROM orders
GROUP BY DATE(order_date);

-- Create index on materialized view
CREATE INDEX idx_mv_daily_sales_date ON mv_daily_sales(sale_date);

-- Refresh periodically
REFRESH MATERIALIZED VIEW mv_daily_sales;

-- Query (fast!)
SELECT * FROM mv_daily_sales
WHERE sale_date >= CURRENT_DATE - INTERVAL '30 days';
```

### 5. Partitioning

```sql
-- Range partitioning by date (PostgreSQL)
CREATE TABLE orders (
    order_id SERIAL,
    order_date DATE NOT NULL,
    total_amount DECIMAL(10, 2)
) PARTITION BY RANGE (order_date);

-- Create partitions
CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');

-- Query automatically uses correct partition
SELECT * FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2024-04-01';
```

---

## Testing and Debugging

### 1. Explain Plan Analysis

```sql
-- PostgreSQL
EXPLAIN ANALYZE
SELECT * FROM orders
WHERE order_date >= '2024-01-01';

-- MySQL
EXPLAIN FORMAT=JSON
SELECT * FROM orders
WHERE order_date >= '2024-01-01';

-- SQL Server
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SELECT * FROM orders
WHERE order_date >= '2024-01-01';
```

### 2. Query Profiling

```sql
-- PostgreSQL: Enable timing
\timing on

-- Check query execution time
SELECT pg_sleep(1);  -- Should take ~1 second

-- MySQL: Profiling
SET profiling = 1;
SELECT * FROM large_table;
SHOW PROFILES;
SHOW PROFILE FOR QUERY 1;
```

### 3. Index Usage Check

```sql
-- PostgreSQL: Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan;

-- MySQL: Check index usage
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    SEQ_IN_INDEX,
    COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'your_database';
```

---

## Best Practices Summary

1. ✅ **Always use EXPLAIN** before deploying queries
2. ✅ **Index foreign keys** and WHERE/JOIN columns
3. ✅ **Avoid SELECT *** - specify columns
4. ✅ **Use batch operations** for bulk inserts/updates
5. ✅ **Prefer JOINs over subqueries** (usually faster)
6. ✅ **Use EXISTS instead of IN** for large subqueries
7. ✅ **Avoid functions on indexed columns** in WHERE
8. ✅ **Use connection pooling** in applications
9. ✅ **Monitor slow query logs** regularly
10. ✅ **Test with production-like data volumes**
