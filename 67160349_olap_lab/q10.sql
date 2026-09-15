-- revenue, orders, AOV (per order) and avg_line (per line) — note the different denominators
SELECT
    SUM(amount)                                           AS revenue,
    COUNT(DISTINCT order_id)                              AS orders,
    ROUND(SUM(amount) * 1.0 / COUNT(DISTINCT order_id), 2) AS aov,
    ROUND(AVG(amount), 2)                                 AS avg_line
FROM sales;
