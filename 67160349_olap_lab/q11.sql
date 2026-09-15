-- Compare row count and total revenue before JOIN (fact_sales) vs after JOIN (sales view)
SELECT 'fact_sales (pre-JOIN)' AS source, COUNT(*) AS line_count, SUM(quantity * unit_price) AS revenue
FROM fact_sales
UNION ALL
SELECT 'sales (post-JOIN)' AS source, COUNT(*) AS line_count, SUM(amount) AS revenue
FROM sales;
