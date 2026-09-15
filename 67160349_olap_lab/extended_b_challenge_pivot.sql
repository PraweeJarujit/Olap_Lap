-- Bonus B: new pivot (province x aug/sep/oct/total) on challenge.db after adding October orders
SELECT
    province,
    SUM(CASE WHEN month = '2026-08' THEN amount ELSE 0 END) AS aug,
    SUM(CASE WHEN month = '2026-09' THEN amount ELSE 0 END) AS sep,
    SUM(CASE WHEN month = '2026-10' THEN amount ELSE 0 END) AS oct,
    SUM(amount) AS total
FROM sales
GROUP BY province
ORDER BY province;
