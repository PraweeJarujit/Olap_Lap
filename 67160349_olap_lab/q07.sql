-- Provinces whose September total exceeds 400, highest revenue first
SELECT province, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY province
HAVING SUM(amount) > 400
ORDER BY revenue DESC;
