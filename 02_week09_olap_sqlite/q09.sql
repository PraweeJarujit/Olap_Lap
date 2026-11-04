-- Subtotal + Grand total ด้วย UNION ALL (ถ้านำทุกแถวมาบวกอีกรอบจะได้ยอด x2 เพราะนับซ้ำ)
SELECT month, SUM(amount) AS revenue FROM sales GROUP BY month
UNION ALL
SELECT 'ALL', SUM(amount) FROM sales;
