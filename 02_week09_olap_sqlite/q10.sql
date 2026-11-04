-- AOV = SUM(amount)/COUNT(DISTINCT order_id) (บาท/ออเดอร์) เทียบ AVG(amount) (บาท/รายการสินค้า)
SELECT SUM(amount) AS revenue,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(1.0 * SUM(amount) / COUNT(DISTINCT order_id), 2) AS aov,
       ROUND(AVG(amount), 2) AS avg_line
FROM sales;
