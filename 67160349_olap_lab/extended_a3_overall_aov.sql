-- Bonus A3: overall AOV across the whole period (extended.db), to compare against the mean of monthly AOVs
SELECT SUM(amount) AS revenue,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(amount) * 1.0 / COUNT(DISTINCT order_id), 2) AS aov_overall
FROM sales;
