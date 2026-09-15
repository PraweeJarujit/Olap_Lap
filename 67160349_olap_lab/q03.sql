-- Add province to the monthly result, ordered by month then province
SELECT month, province, SUM(amount) AS revenue
FROM sales
GROUP BY month, province
ORDER BY month, province;
