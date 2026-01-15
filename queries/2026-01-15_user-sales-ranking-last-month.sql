-- Query Purpose: 先月のユーザー別売上ランキング（購入商品詳細付き）
-- Created: 2026-01-15 20:47:48
-- Environment: production
-- Database: MySQL 8.0

-- @query-metadata
-- purpose: 先月のユーザー別売上ランキング（購入商品詳細付き）
-- database: MySQL 8.0
-- environment: production
-- created_by: @query-designer
-- created_at: 2026-01-15 20:46:00

SELECT 
    u.user_id,
    u.username,
    u.email,
    SUM(o.total_amount) AS total_sales_amount,
    COUNT(DISTINCT o.order_id) AS order_count,
    GROUP_CONCAT(DISTINCT p.product_name ORDER BY p.product_name SEPARATOR ', ') AS purchased_products_list
FROM 
    users u
    INNER JOIN orders o ON u.user_id = o.user_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
WHERE 
    o.order_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
    AND o.status = 'completed'
GROUP BY 
    u.user_id, u.username, u.email
ORDER BY 
    total_sales_amount DESC;
