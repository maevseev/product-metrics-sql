WITH revenue_per_day AS (SELECT date, 
COUNT(DISTINCT order_id) AS order_count, 
SUM(price) AS revenue_per_day,
SUM(tax) AS tax_per_day,
CASE
    WHEN EXTRACT(month FROM date) = 8 THEN 120000
    WHEN EXTRACT(month FROM date) = 9 THEN 150000
END AS regular_costs
FROM
(SELECT date, order_id, t1.product_id, name, price, 
CASE 
    WHEN name IN ('сахар', 'сухарики', 'сушки', 'семечки', 
'масло льняное', 'виноград', 'масло оливковое', 
'арбуз', 'батон', 'йогурт', 'сливки', 'гречка', 
'овсянка', 'макароны', 'баранина', 'апельсины', 
'бублики', 'хлеб', 'горох', 'сметана', 'рыба копченая', 
'мука', 'шпроты', 'сосиски', 'свинина', 'рис', 
'масло кунжутное', 'сгущенка', 'ананас', 'говядина', 
'соль', 'рыба вяленая', 'масло подсолнечное', 'яблоки', 
'груши', 'лепешка', 'молоко', 'курица', 'лаваш', 'вафли', 'мандарины') THEN ROUND((0.1 * price) :: DECIMAL / 1.1, 2)
    ELSE ROUND((0.2 * price) :: DECIMAL / 1.2, 2)
    END AS tax
FROM
(SELECT creation_time :: DATE AS date, order_id, UNNEST(product_ids) AS product_id FROM orders
WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')) t1
LEFT JOIN products 
ON t1.product_id = products.product_id) t2
GROUP BY date),

good_couriers_per_day AS (SELECT date, COUNT(DISTINCT courier_id) FILTER(WHERE orders_per_courier >= 5) AS good_couriers FROM 
(SELECT DISTINCT time::DATE AS date, courier_id, COUNT(order_id) OVER (PARTITION BY time::date, courier_id) AS orders_per_courier 
FROM courier_actions
WHERE action = 'deliver_order' AND order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
ORDER BY date, orders_per_courier DESC) t3
GROUP BY date),

delivery_costs_per_day AS (SELECT time::date as date, 150 * COUNT(order_id) AS delivery_costs
FROM courier_actions
WHERE action = 'deliver_order' AND order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
GROUP BY date
ORDER BY date),

assempbly_costs_per_day AS (SELECT creation_time::date as date,
CASE
    WHEN EXTRACT(month FROM creation_time::date) = 8 THEN 140 * COUNT(order_id)
    WHEN EXTRACT(month FROM creation_time::date) = 9 THEN 115 * COUNT(order_id)
END AS assempbly_costs
FROM orders
WHERE order_id NOT IN (SELECT order_id FROM user_actions WHERE action = 'cancel_order')
GROUP BY date
ORDER BY date),

variable_costs_per_day AS (SELECT date,
CASE
    WHEN EXTRACT(month FROM date) = 8 THEN (assempbly_costs + delivery_costs + good_couriers * 400)
    WHEN EXTRACT(month FROM date) = 9 THEN (assempbly_costs + delivery_costs + good_couriers * 500)
END AS variable_costs
FROM delivery_costs_per_day LEFT JOIN assempbly_costs_per_day USING(date)
LEFT JOIN good_couriers_per_day USING(date)),

basic_metrics AS (SELECT revenue_per_day.date, revenue_per_day AS revenue, 
ROUND(variable_costs + regular_costs, 2) AS costs,
tax_per_day AS tax, 
revenue_per_day - (variable_costs + regular_costs + tax_per_day) AS gross_profit
FROM revenue_per_day LEFT JOIN variable_costs_per_day USING(date))

SELECT date, revenue, costs, tax, gross_profit, 
SUM(revenue) OVER (ORDER BY date) AS total_revenue, 
SUM(costs) OVER (ORDER BY date) AS total_costs, 
SUM(tax) OVER (ORDER BY date) AS total_tax, 
SUM(gross_profit) OVER (ORDER BY date) AS total_gross_profit,
ROUND(100 * gross_profit :: DECIMAL / revenue, 2) AS gross_profit_ratio,
ROUND(100 * SUM(gross_profit) OVER (ORDER BY date) :: DECIMAL / SUM(revenue) OVER (ORDER BY date), 2) AS total_gross_profit_ratio
FROM basic_metrics
