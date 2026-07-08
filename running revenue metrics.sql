WITH order_prices AS (SELECT DISTINCT date, order_id, SUM(price) OVER (PARTITION BY order_id) AS order_price FROM
(SELECT creation_time :: DATE AS date, order_id, UNNEST(product_ids) AS product_id FROM orders
WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
LEFT JOIN products 
ON t1.product_id = products.product_id),
order_count AS (SELECT time::date AS date, 
count(distinct order_id) filter (WHERE order_id not in (SELECT order_id FROM user_actions WHERE  action = 'cancel_order')) as order_count
FROM   user_actions GROUP BY date),
revenue_info AS (SELECT DISTINCT order_prices.date, order_count,
SUM(order_price) OVER (PARTITION BY order_prices.date ORDER BY order_prices.date) AS revenue,
SUM(order_price) OVER (ORDER BY order_prices.date) AS total_revenue 
FROM order_prices LEFT JOIN order_count 
ON order_prices.date = order_count.date
ORDER BY order_prices.date),
running_user_info AS (SELECT t2.date, COUNT(DISTINCT user_id) FILTER (WHERE date_of_first_action <= t2.date) AS running_active_users,
COUNT(DISTINCT user_id) FILTER (WHERE date_of_first_order <= t2.date) AS running_paying_users
FROM (SELECT DISTINCT user_id, MIN(time::DATE) OVER (PARTITION BY user_id) AS date_of_first_action,
MIN(time::DATE) FILTER (WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order'))
OVER (PARTITION BY user_id) AS date_of_first_order
FROM user_actions) t1
CROSS JOIN (SELECT date FROM revenue_info) t2
GROUP BY t2.date)
SELECT running_user_info.date, 
ROUND(total_revenue :: DECIMAL / running_active_users, 2) AS running_arpu,
ROUND(total_revenue :: DECIMAL / running_paying_users, 2) AS running_arppu,
ROUND(total_revenue :: DECIMAL / SUM(order_count) OVER (ORDER BY revenue_info.date), 2) AS running_aov
FROM running_user_info LEFT JOIN revenue_info
ON running_user_info.date = revenue_info.date
ORDER BY running_user_info.date
