WITH order_prices AS (SELECT DISTINCT date, order_id, SUM(price) OVER (PARTITION BY order_id) AS order_price FROM
(SELECT creation_time :: DATE AS date, order_id, UNNEST(product_ids) AS product_id FROM orders
WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
LEFT JOIN products 
ON t1.product_id = products.product_id),

revenue_info AS (SELECT DISTINCT date, 
SUM(order_price) OVER (PARTITION BY date ORDER BY date) AS revenue,
SUM(order_price) OVER (ORDER BY date) AS total_revenue FROM order_prices
ORDER BY date),

user_info_per_date AS (SELECT time::date as date, 
COUNT(DISTINCT order_id)  FILTER (WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) AS order_count, 
COUNT(DISTINCT user_id) FILTER (WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) AS paying_users,
COUNT(DISTINCT user_id) AS active_users 
FROM user_actions
GROUP BY date)

SELECT user_info_per_date.date, 
ROUND(revenue :: DECIMAL / active_users, 2) AS arpu,
ROUND(revenue :: DECIMAL / paying_users, 2) AS arppu,
ROUND(revenue :: DECIMAL / order_count, 2) AS aov
FROM user_info_per_date LEFT JOIN revenue_info
ON user_info_per_date.date = revenue_info.date
ORDER BY date
