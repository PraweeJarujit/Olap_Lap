-- Drill-down on time: daily revenue for September only
SELECT full_date, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY full_date
ORDER BY full_date;
