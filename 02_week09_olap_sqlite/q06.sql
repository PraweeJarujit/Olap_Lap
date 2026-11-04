-- Dice: หลายเงื่อนไขหลายมิติ (กันยายน + Drink + Bangkok/Chonburi)
SELECT province, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
  AND category = 'Drink'
  AND province IN ('Bangkok', 'Chonburi')
GROUP BY province
ORDER BY province;
