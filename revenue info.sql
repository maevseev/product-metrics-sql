WITH order_prices AS (SELECT DISTINCT date, order_id, SUM(price) OVER (PARTITION BY order_id) AS order_price FROM
(SELECT creation_time :: DATE AS date, order_id, UNNEST(product_ids) AS product_id FROM orders
WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
LEFT JOIN products 
ON t1.product_id = products.product_id),
revenue_info AS (SELECT DISTINCT date, 
SUM(order_price) OVER (PARTITION BY date ORDER BY date) AS revenue,
SUM(order_price) OVER (ORDER BY date) AS total_revenue FROM order_prices
ORDER BY date)

SELECT date, revenue, total_revenue, 
ROUND(100 * (revenue - LAG(revenue, 1) OVER (ORDER BY date)) :: DECIMAL / LAG(revenue, 1) OVER (ORDER BY date), 2) AS revenue_change
FROM revenue_info
