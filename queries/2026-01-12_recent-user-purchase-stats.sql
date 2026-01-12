-- Query Purpose: 直近1ヶ月以内のユーザーの購買統計（商品別詳細、総購入金額、注文回数）
-- Created: 2026-01-12 17:58:00
-- Environment: dev
-- Database: MySQL 8.0

-- ユーザーごとの購買統計（商品をJSON配列で集約）
WITH recent_users AS (
    SELECT user_id, username, email
    FROM users
    WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
      AND status = 'active'
),
user_product_details AS (
    SELECT 
        u.user_id,
        u.username,
        u.email,
        p.product_name,
        SUM(oi.quantity) AS quantity,
        SUM(oi.quantity * oi.unit_price) AS amount
    FROM recent_users u
    INNER JOIN orders o ON u.user_id = o.user_id
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    WHERE o.status = 'completed'
    GROUP BY u.user_id, u.username, u.email, p.product_name
),
user_summary AS (
    SELECT 
        user_id,
        username,
        email,
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_name', product_name,
                'quantity', quantity,
                'amount', amount
            )
        ) AS purchased_products,
        SUM(amount) AS total_purchase_amount,
        COUNT(DISTINCT product_name) AS unique_products_count
    FROM user_product_details
    GROUP BY user_id, username, email
),
user_order_count AS (
    SELECT 
        u.user_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM recent_users u
    INNER JOIN orders o ON u.user_id = o.user_id
    WHERE o.status = 'completed'
    GROUP BY u.user_id
)
SELECT 
    s.user_id,
    s.username,
    s.email,
    s.purchased_products,
    s.total_purchase_amount,
    oc.order_count,
    s.unique_products_count
FROM user_summary s
INNER JOIN user_order_count oc ON s.user_id = oc.user_id
ORDER BY s.total_purchase_amount DESC;
