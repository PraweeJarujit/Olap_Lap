-- Bonus A1: top 3 stores by total revenue (extended.db)
SELECT store_name, province, SUM(amount) AS revenue
FROM sales
GROUP BY store_name, province
ORDER BY revenue DESC
LIMIT 3;
