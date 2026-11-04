-- Slice: ตัดมิติเวลาเหลือกันยายน แล้วสรุปตามจังหวัด
SELECT province, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY province
ORDER BY province;
