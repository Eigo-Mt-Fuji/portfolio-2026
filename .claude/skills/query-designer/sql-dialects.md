# SQL Dialects Reference

This document provides SQL dialect-specific syntax and features for the Query Designer skill.

## PostgreSQL

### Version Support
- PostgreSQL 12+
- PostgreSQL 13+ (recommended)
- PostgreSQL 14+ (latest features)

### Unique Features

#### 1. JSONB Operations

```sql
-- JSONB column query
SELECT 
    id,
    data->>'name' AS name,
    data->'address'->>'city' AS city
FROM 
    users
WHERE 
    data @> '{"status": "active"}';

-- JSONB aggregation
SELECT 
    jsonb_agg(
        jsonb_build_object(
            'id', user_id,
            'name', username
        )
    ) AS users_json
FROM users;
```

#### 2. Array Operations

```sql
-- Array contains
SELECT * FROM products
WHERE tags @> ARRAY['electronics', 'sale'];

-- Array overlap
SELECT * FROM products
WHERE tags && ARRAY['new', 'featured'];

-- Array to rows
SELECT unnest(ARRAY[1, 2, 3, 4, 5]);
```

#### 3. Full-Text Search

```sql
-- Create tsvector column
ALTER TABLE articles 
ADD COLUMN search_vector tsvector;

-- Update search vector
UPDATE articles 
SET search_vector = to_tsvector('english', title || ' ' || content);

-- Full-text search
SELECT * FROM articles
WHERE search_vector @@ to_tsquery('english', 'postgresql & performance');

-- Ranking
SELECT 
    title,
    ts_rank(search_vector, query) AS rank
FROM 
    articles,
    to_tsquery('english', 'database') AS query
WHERE 
    search_vector @@ query
ORDER BY 
    rank DESC;
```

#### 4. Window Functions (Advanced)

```sql
-- FILTER clause
SELECT 
    department,
    COUNT(*) AS total_employees,
    COUNT(*) FILTER (WHERE salary > 50000) AS high_earners
FROM employees
GROUP BY department;

-- RANGE frame
SELECT 
    order_date,
    total_amount,
    AVG(total_amount) OVER (
        ORDER BY order_date
        RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
    ) AS moving_avg_7days
FROM orders;
```

#### 5. CTEs with MATERIALIZED

```sql
-- Materialized CTE (force materialization)
WITH MATERIALIZED recent_orders AS (
    SELECT * FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT * FROM recent_orders;

-- Not materialized (inline)
WITH NOT MATERIALIZED recent_orders AS (
    SELECT * FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
)
SELECT * FROM recent_orders;
```

#### 6. LATERAL JOIN

```sql
-- Get top 3 products per category
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

---

## MySQL

### Version Support
- MySQL 8.0+ (recommended for window functions and CTEs)
- MySQL 5.7 (limited features)

### Unique Features

#### 1. JSON Functions

```sql
-- JSON extraction
SELECT 
    id,
    JSON_EXTRACT(data, '$.name') AS name,
    JSON_UNQUOTE(JSON_EXTRACT(data, '$.email')) AS email,
    data->>'$.city' AS city  -- MySQL 8.0+
FROM users;

-- JSON modification
UPDATE users
SET data = JSON_SET(data, '$.status', 'active')
WHERE id = 1;

-- JSON array
SELECT 
    id,
    JSON_LENGTH(tags) AS tag_count
FROM products
WHERE JSON_CONTAINS(tags, '"electronics"');
```

#### 2. Date Functions

```sql
-- Date arithmetic
SELECT 
    order_date,
    DATE_ADD(order_date, INTERVAL 7 DAY) AS delivery_date,
    DATE_SUB(CURDATE(), INTERVAL 30 DAY) AS thirty_days_ago
FROM orders;

-- Date formatting
SELECT 
    DATE_FORMAT(order_date, '%Y-%m-%d') AS formatted_date,
    DATE_FORMAT(created_at, '%W, %M %d, %Y') AS long_format
FROM orders;
```

#### 3. String Functions

```sql
-- String manipulation
SELECT 
    CONCAT(first_name, ' ', last_name) AS full_name,
    SUBSTRING(email, 1, LOCATE('@', email) - 1) AS username,
    REPLACE(phone, '-', '') AS phone_clean
FROM users;

-- Regular expressions (MySQL 8.0+)
SELECT * FROM users
WHERE email REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
```

#### 4. Window Functions (MySQL 8.0+)

```sql
-- Row number and ranking
SELECT 
    product_name,
    category,
    price,
    ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC) AS row_num,
    RANK() OVER (PARTITION BY category ORDER BY price DESC) AS price_rank,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY price DESC) AS dense_rank
FROM products;
```

#### 5. CTEs (MySQL 8.0+)

```sql
-- Recursive CTE for hierarchical data
WITH RECURSIVE category_tree AS (
    SELECT id, name, parent_id, 1 AS level
    FROM categories
    WHERE parent_id IS NULL
    
    UNION ALL
    
    SELECT c.id, c.name, c.parent_id, ct.level + 1
    FROM categories c
    INNER JOIN category_tree ct ON c.parent_id = ct.id
)
SELECT * FROM category_tree
ORDER BY level, name;
```

#### 6. Index Hints

```sql
-- Force index usage
SELECT * FROM orders
USE INDEX (idx_order_date)
WHERE order_date >= '2024-01-01';

-- Ignore index
SELECT * FROM orders
IGNORE INDEX (idx_customer_id)
WHERE customer_id = 123;
```

---

## SQLite

### Version Support
- SQLite 3.35+ (window functions)
- SQLite 3.38+ (recommended)

### Limitations and Workarounds

#### 1. No RIGHT JOIN or FULL OUTER JOIN

```sql
-- Workaround for RIGHT JOIN: swap tables and use LEFT JOIN
-- Instead of: A RIGHT JOIN B
-- Use: B LEFT JOIN A

-- Workaround for FULL OUTER JOIN: UNION of LEFT and RIGHT
SELECT * FROM a LEFT JOIN b ON a.id = b.a_id
UNION
SELECT * FROM a RIGHT JOIN b ON a.id = b.a_id;

-- Better: Use LEFT JOIN with UNION
SELECT a.*, b.*
FROM a LEFT JOIN b ON a.id = b.a_id
UNION ALL
SELECT a.*, b.*
FROM b LEFT JOIN a ON b.a_id = a.id
WHERE a.id IS NULL;
```

#### 2. Limited Date Functions

```sql
-- Date arithmetic
SELECT 
    date('now') AS today,
    date('now', '-30 days') AS thirty_days_ago,
    date('now', '+7 days') AS week_later,
    datetime('now', 'localtime') AS local_datetime;

-- Date formatting
SELECT 
    strftime('%Y-%m-%d', order_date) AS formatted_date,
    strftime('%Y', order_date) AS year,
    strftime('%m', order_date) AS month
FROM orders;
```

#### 3. No BOOLEAN Type

```sql
-- Use INTEGER (0 = false, 1 = true)
CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    is_active INTEGER DEFAULT 1,  -- 0 or 1
    CHECK (is_active IN (0, 1))
);

-- Query
SELECT * FROM users WHERE is_active = 1;
```

#### 4. Limited Window Functions

```sql
-- Supported window functions (SQLite 3.25+)
SELECT 
    product_name,
    price,
    ROW_NUMBER() OVER (ORDER BY price DESC) AS row_num,
    RANK() OVER (ORDER BY price DESC) AS price_rank,
    LAG(price) OVER (ORDER BY price) AS prev_price,
    LEAD(price) OVER (ORDER BY price) AS next_price
FROM products;

-- Not supported: FILTER clause
-- Workaround: Use CASE
SELECT 
    department,
    COUNT(*) AS total,
    SUM(CASE WHEN salary > 50000 THEN 1 ELSE 0 END) AS high_earners
FROM employees
GROUP BY department;
```

#### 5. JSON Support (SQLite 3.38+)

```sql
-- JSON functions
SELECT 
    json_extract(data, '$.name') AS name,
    json_extract(data, '$.address.city') AS city
FROM users;

-- JSON array
SELECT value
FROM json_each('["apple", "banana", "cherry"]');
```

---

## SQL Server (T-SQL)

### Version Support
- SQL Server 2016+ (recommended)
- SQL Server 2019+ (latest features)

### Unique Features

#### 1. TOP with PERCENT

```sql
-- Top 10 percent
SELECT TOP 10 PERCENT *
FROM products
ORDER BY price DESC;

-- Top with TIES
SELECT TOP 5 WITH TIES
    product_name,
    price
FROM products
ORDER BY price DESC;
```

#### 2. CROSS APPLY / OUTER APPLY

```sql
-- CROSS APPLY (like INNER JOIN with table-valued function)
SELECT 
    c.customer_name,
    o.order_id,
    o.total_amount
FROM 
    customers c
    CROSS APPLY (
        SELECT TOP 3 order_id, total_amount
        FROM orders
        WHERE customer_id = c.customer_id
        ORDER BY order_date DESC
    ) o;

-- OUTER APPLY (like LEFT JOIN)
SELECT 
    c.customer_name,
    o.order_id,
    o.total_amount
FROM 
    customers c
    OUTER APPLY (
        SELECT TOP 3 order_id, total_amount
        FROM orders
        WHERE customer_id = c.customer_id
        ORDER BY order_date DESC
    ) o;
```

#### 3. PIVOT / UNPIVOT

```sql
-- PIVOT: rows to columns
SELECT *
FROM (
    SELECT year, quarter, sales_amount
    FROM sales
) AS source_table
PIVOT (
    SUM(sales_amount)
    FOR quarter IN ([Q1], [Q2], [Q3], [Q4])
) AS pivot_table;

-- UNPIVOT: columns to rows
SELECT year, quarter, sales_amount
FROM sales_by_quarter
UNPIVOT (
    sales_amount FOR quarter IN ([Q1], [Q2], [Q3], [Q4])
) AS unpivot_table;
```

#### 4. STRING_AGG (SQL Server 2017+)

```sql
-- Concatenate strings
SELECT 
    category_id,
    STRING_AGG(product_name, ', ') AS products
FROM products
GROUP BY category_id;

-- With ordering
SELECT 
    category_id,
    STRING_AGG(product_name, ', ') WITHIN GROUP (ORDER BY price DESC) AS products
FROM products
GROUP BY category_id;
```

#### 5. OFFSET-FETCH (Pagination)

```sql
-- Skip first 20, take next 10
SELECT *
FROM products
ORDER BY product_id
OFFSET 20 ROWS
FETCH NEXT 10 ROWS ONLY;
```

#### 6. Temporal Tables (System-Versioned)

```sql
-- Create temporal table
CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    name NVARCHAR(100),
    salary DECIMAL(10, 2),
    valid_from DATETIME2 GENERATED ALWAYS AS ROW START,
    valid_to DATETIME2 GENERATED ALWAYS AS ROW END,
    PERIOD FOR SYSTEM_TIME (valid_from, valid_to)
)
WITH (SYSTEM_VERSIONING = ON);

-- Query historical data
SELECT * FROM employees
FOR SYSTEM_TIME AS OF '2024-01-01';

-- Query all history
SELECT * FROM employees
FOR SYSTEM_TIME ALL;
```

---

## Dialect Conversion Tips

### PostgreSQL → MySQL

```sql
-- PostgreSQL: INTERVAL
WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'

-- MySQL: DATE_SUB
WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
```

### PostgreSQL → SQLite

```sql
-- PostgreSQL: CURRENT_DATE
WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'

-- SQLite: date()
WHERE order_date >= date('now', '-30 days')
```

### MySQL → PostgreSQL

```sql
-- MySQL: LIMIT offset, count
SELECT * FROM products
ORDER BY price
LIMIT 10, 20;

-- PostgreSQL: LIMIT count OFFSET offset
SELECT * FROM products
ORDER BY price
LIMIT 20 OFFSET 10;
```

### SQL Server → PostgreSQL

```sql
-- SQL Server: TOP
SELECT TOP 10 * FROM products
ORDER BY price DESC;

-- PostgreSQL: LIMIT
SELECT * FROM products
ORDER BY price DESC
LIMIT 10;
```

---

## Performance Considerations by Dialect

### PostgreSQL
- ✅ Excellent for complex queries with CTEs
- ✅ Best JSONB performance
- ✅ Advanced indexing (GiST, GIN, BRIN)
- ⚠️ Vacuum required for optimal performance

### MySQL
- ✅ Fast for simple queries
- ✅ Good for read-heavy workloads
- ⚠️ Limited window function performance (vs PostgreSQL)
- ⚠️ InnoDB required for transactions

### SQLite
- ✅ Extremely fast for embedded use
- ✅ Zero configuration
- ⚠️ Single writer limitation
- ⚠️ Not suitable for high concurrency

### SQL Server
- ✅ Enterprise features (partitioning, compression)
- ✅ Excellent query optimizer
- ✅ Columnstore indexes for analytics
- ⚠️ Licensing costs
