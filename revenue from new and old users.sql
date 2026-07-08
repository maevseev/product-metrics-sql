WITH order_prices AS (SELECT DISTINCT date, t1.order_id, user_id, SUM(price) OVER (PARTITION BY t1.order_id) AS order_price FROM
(SELECT creation_time :: DATE AS date, order_id, UNNEST(product_ids) AS product_id FROM orders
WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
LEFT JOIN products 
ON t1.product_id = products.product_id
LEFT JOIN user_actions
ON t1.order_id = user_actions.order_id),

new_users_per_day AS (SELECT DISTINCT date, 
ARRAY_AGG(user_id) OVER (PARTITION BY date) as new_users
FROM   (SELECT user_id, order_id, row_number() OVER (PARTITION BY user_id ORDER BY time) as action_number, time::date as date
FROM user_actions) t1
WHERE  action_number = 1),

revenue_info AS (SELECT DISTINCT order_prices.date, 
SUM(order_price) OVER (PARTITION BY order_prices.date ORDER BY order_prices.date) AS revenue,
SUM(order_price) FILTER (WHERE user_id = ANY(new_users))
OVER (PARTITION BY order_prices.date ORDER BY order_prices.date) AS new_users_revenue,
SUM(order_price) FILTER (WHERE user_id <> ALL(new_users)) 
OVER (PARTITION BY order_prices.date ORDER BY order_prices.date) AS old_users_revenue
FROM order_prices LEFT JOIN new_users_per_day
ON order_prices.date = new_users_per_day.date
ORDER BY order_prices.date)

SELECT date, revenue, new_users_revenue, 
ROUND(100 * new_users_revenue::DECIMAL / revenue, 2) AS new_users_revenue_share, 
ROUND(100 * (revenue - new_users_revenue)::DECIMAL / revenue, 2) AS old_users_revenue_share
FROM revenue_info
