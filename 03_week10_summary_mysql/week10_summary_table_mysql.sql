-- =====================================================================
-- Lab Week 10 — Aggregate / Summary Table  (MySQL 8 / MariaDB + phpMyAdmin)
-- วิธีใช้: phpMyAdmin > แท็บ SQL > วางทั้งไฟล์ > Go   (หรือ Import ไฟล์นี้)
-- ทุกข้อมีหัว "ข้อ n" ตรงกับใบงาน และมีค่าที่ควรได้ (Expected) กำกับไว้
-- =====================================================================

-- ---------------------------------------------------------------------
-- ข้อ 1  สร้างฐานข้อมูลและตาราง fact_sales + นำเข้าข้อมูล 30 แถว
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS dw_lab10 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE dw_lab10;

DROP TABLE IF EXISTS summary_sales_month_product;
DROP TABLE IF EXISTS fact_sales;

CREATE TABLE fact_sales (
    sale_id     INT            NOT NULL,          -- ไม่ซ้ำ -> Primary Key (Grain = 1 แถวต่อ 1 รายการขาย)
    order_date  DATE           NOT NULL,
    product_id  VARCHAR(10)    NOT NULL,
    qty         INT            NOT NULL,          -- additive
    amount      DECIMAL(10,2)  NOT NULL,          -- additive, ใช้ DECIMAL ไม่ใช้ FLOAT เพราะเป็นเงิน
    PRIMARY KEY (sale_id),
    INDEX idx_date_product (order_date, product_id),
    CONSTRAINT chk_qty    CHECK (qty > 0),
    CONSTRAINT chk_amount CHECK (amount >= 0)
) ENGINE = InnoDB;

INSERT INTO fact_sales (sale_id, order_date, product_id, qty, amount) VALUES
-- ชุดข้อมูล A
( 1,'2025-01-03','P101',2, 398.00),( 2,'2025-01-05','P102',1, 249.00),( 3,'2025-01-06','P103',3, 597.00),
( 4,'2025-01-08','P101',1, 199.00),( 5,'2025-01-10','P104',2, 698.00),( 6,'2025-01-12','P105',1, 459.00),
( 7,'2025-01-15','P102',2, 498.00),( 8,'2025-01-18','P103',1, 199.00),( 9,'2025-01-22','P104',1, 349.00),
(10,'2025-01-27','P101',3, 597.00),(11,'2025-02-02','P105',2, 918.00),(12,'2025-02-04','P101',1, 199.00),
(13,'2025-02-07','P102',3, 747.00),(14,'2025-02-09','P104',1, 349.00),(15,'2025-02-11','P103',2, 398.00),
-- ชุดข้อมูล B
(16,'2025-02-14','P101',2, 398.00),(17,'2025-02-17','P105',1, 459.00),(18,'2025-02-20','P102',1, 249.00),
(19,'2025-02-24','P103',4, 796.00),(20,'2025-02-28','P104',2, 698.00),(21,'2025-03-01','P101',1, 199.00),
(22,'2025-03-03','P102',2, 498.00),(23,'2025-03-05','P103',1, 199.00),(24,'2025-03-08','P104',3,1047.00),
(25,'2025-03-10','P105',2, 918.00),(26,'2025-03-13','P101',4, 796.00),(27,'2025-03-17','P102',1, 249.00),
(28,'2025-03-21','P103',2, 398.00),(29,'2025-03-25','P105',1, 459.00),(30,'2025-03-29','P104',1, 349.00);

-- ---------------------------------------------------------------------
-- ข้อ 2  ตรวจสอบข้อมูลก่อน Aggregate
-- Expected: 30 แถว | 2025-01-03 ถึง 2025-03-29 | 5 สินค้า | qty 54 | amount 14,566.00
-- ---------------------------------------------------------------------
SELECT COUNT(*)                   AS total_rows,
       MIN(order_date)            AS min_date,
       MAX(order_date)            AS max_date,
       COUNT(DISTINCT product_id) AS distinct_products,
       SUM(qty)                   AS total_qty,
       SUM(amount)                AS total_amount
FROM fact_sales;

SELECT * FROM fact_sales ORDER BY sale_id LIMIT 10;      -- ตัวอย่าง 10 แถว

-- ข้อสังเกต: ราคาต่อชิ้นคงที่ต่อสินค้า (P101=199, P102=249, P103=199, P104=349, P105=459)
SELECT product_id, MIN(amount/qty) AS min_unit_price, MAX(amount/qty) AS max_unit_price, COUNT(*) AS n
FROM fact_sales GROUP BY product_id ORDER BY product_id;

-- ---------------------------------------------------------------------
-- ข้อ 3  ออกแบบ (ตอบในรายงาน)
--   Grain       = 1 แถว ต่อ 1 เดือน × 1 สินค้า (sales_month, product_id)
--   Columns     = sales_month, product_id, revenue, quantity, order_count, last_refreshed
--   Primary Key = (sales_month, product_id)  ต้องตรงกับ Grain พอดี
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- ข้อ 4  Baseline Query จาก fact_sales   Expected: 15 แถว (3 เดือน × 5 สินค้า)
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(order_date, '%Y-%m') AS sales_month,
       product_id,
       SUM(amount) AS revenue,
       SUM(qty)    AS quantity,
       COUNT(*)    AS order_count
FROM fact_sales
GROUP BY DATE_FORMAT(order_date, '%Y-%m'), product_id
ORDER BY sales_month, product_id;

-- ---------------------------------------------------------------------
-- ข้อ 5  สร้าง Summary Table
-- ---------------------------------------------------------------------
CREATE TABLE summary_sales_month_product (
    sales_month    CHAR(7)        NOT NULL,       -- 'YYYY-MM'
    product_id     VARCHAR(10)    NOT NULL,
    revenue        DECIMAL(12,2)  NOT NULL,
    quantity       INT            NOT NULL,
    order_count    INT            NOT NULL,
    last_refreshed DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (sales_month, product_id)
) ENGINE = InnoDB;

INSERT INTO summary_sales_month_product (sales_month, product_id, revenue, quantity, order_count, last_refreshed)
SELECT DATE_FORMAT(order_date, '%Y-%m'), product_id, SUM(amount), SUM(qty), COUNT(*), NOW()
FROM fact_sales
GROUP BY DATE_FORMAT(order_date, '%Y-%m'), product_id;

-- ---------------------------------------------------------------------
-- ข้อ 6  Query จาก Summary Table (คำถามเดียวกับ Baseline) -> ต้องได้ 15 แถวและค่าตรงกัน
-- ---------------------------------------------------------------------
SELECT sales_month, product_id, revenue, quantity, order_count
FROM summary_sales_month_product
ORDER BY sales_month, product_id;

-- Expected (ข้อ 4 = ข้อ 6):
-- 2025-01 P101 1194 6 3 | P102  747 3 2 | P103  796 4 2 | P104 1047 3 2 | P105  459 1 1
-- 2025-02 P101  597 3 2 | P102  996 4 2 | P103 1194 6 2 | P104 1047 3 2 | P105 1377 3 2
-- 2025-03 P101  995 5 2 | P102  747 3 2 | P103  597 3 2 | P104 1396 4 2 | P105 1377 3 2

-- ---------------------------------------------------------------------
-- ข้อ 7  EXPLAIN เปรียบเทียบ   (MySQL 8.0.18+ ใช้ EXPLAIN ANALYZE ได้เวลาจริง)
--   fact_sales:   rows ≈ 30 + "Using temporary" (ต้อง GROUP BY ทุกครั้ง)
--   summary:      rows ≈ 15, ไม่มี temporary/filesort เพราะสรุปไว้แล้ว และ PK เรียงตาม (month, product)
-- ---------------------------------------------------------------------
EXPLAIN
SELECT DATE_FORMAT(order_date, '%Y-%m') AS sales_month, product_id,
       SUM(amount), SUM(qty), COUNT(*)
FROM fact_sales
GROUP BY DATE_FORMAT(order_date, '%Y-%m'), product_id
ORDER BY sales_month, product_id;

EXPLAIN
SELECT sales_month, product_id, revenue, quantity, order_count
FROM summary_sales_month_product
ORDER BY sales_month, product_id;

-- เวลา Query: ดูได้ที่ข้อความ "Query took x.xxxx seconds" ใน phpMyAdmin
-- หรือ  SET profiling = 1;  <รัน query>;  SHOW PROFILES;

-- ---------------------------------------------------------------------
-- ข้อ 8  Validation: ยอดรวมจาก fact = จาก summary   Expected: 14566.00 | 54 | 30 ตรงกันทุกค่า
-- ---------------------------------------------------------------------
SELECT 'Revenue' AS metric,
       (SELECT SUM(amount) FROM fact_sales)                  AS from_fact_sales,
       (SELECT SUM(revenue) FROM summary_sales_month_product) AS from_summary,
       (SELECT SUM(amount) FROM fact_sales) = (SELECT SUM(revenue) FROM summary_sales_month_product) AS is_match
UNION ALL
SELECT 'Quantity',
       (SELECT SUM(qty) FROM fact_sales),
       (SELECT SUM(quantity) FROM summary_sales_month_product),
       (SELECT SUM(qty) FROM fact_sales) = (SELECT SUM(quantity) FROM summary_sales_month_product)
UNION ALL
SELECT 'Order Count',
       (SELECT COUNT(*) FROM fact_sales),
       (SELECT SUM(order_count) FROM summary_sales_month_product),
       (SELECT COUNT(*) FROM fact_sales) = (SELECT SUM(order_count) FROM summary_sales_month_product);

-- ตรวจละเอียดระดับแถว: แถวไหนไม่ตรง (ผลว่าง = ตรงทั้งหมด)
SELECT b.sales_month, b.product_id, b.revenue AS fact_rev, s.revenue AS summary_rev
FROM (SELECT DATE_FORMAT(order_date,'%Y-%m') AS sales_month, product_id, SUM(amount) AS revenue
      FROM fact_sales GROUP BY DATE_FORMAT(order_date,'%Y-%m'), product_id) b
LEFT JOIN summary_sales_month_product s
       ON s.sales_month = b.sales_month AND s.product_id = b.product_id
WHERE s.revenue IS NULL OR s.revenue <> b.revenue;

-- ---------------------------------------------------------------------
-- ข้อ 9  Data Stale: เพิ่มรายการใหม่ แล้ว Summary ไม่เปลี่ยน
-- ---------------------------------------------------------------------
INSERT INTO fact_sales (sale_id, order_date, product_id, qty, amount)
VALUES (31, '2025-03-31', 'P101', 2, 1000.00);

-- fact: 2025-03 P101 = 1995.00 (995+1000), qty 7, 3 รายการ  | summary ยังเป็น 995.00, 5, 2  -> ไม่ตรง
SELECT 'fact_sales (ล่าสุด)' AS source, SUM(amount) AS revenue, SUM(qty) AS quantity, COUNT(*) AS order_count
FROM fact_sales WHERE order_date >= '2025-03-01' AND order_date < '2025-04-01' AND product_id = 'P101'
UNION ALL
SELECT 'summary (ค้าง/stale)', revenue, quantity, order_count
FROM summary_sales_month_product WHERE sales_month = '2025-03' AND product_id = 'P101';
-- เหตุผล: Summary Table เป็นตารางจริงที่ "คำนวณไว้ล่วงหน้า" ณ เวลาที่ INSERT...SELECT
--         ไม่ได้ผูกกับ fact_sales แบบ View จึงไม่อัปเดตเองจนกว่าจะ Refresh -> ข้อมูลล้าสมัย (stale)
-- ข้อสังเกตคุณภาพข้อมูล: P101 ราคา 199/ชิ้น ดังนั้น 2 ชิ้นควร = 398 แต่บันทึก 1,000 (500/ชิ้น)
--         -> ควร flag ตรวจสอบก่อนนำเข้า (ราคาผิด/โปรโมชัน/คีย์ผิด)
SELECT sale_id, product_id, qty, amount, amount/qty AS unit_price_calc
FROM fact_sales WHERE amount/qty <> (SELECT MIN(amount/qty) FROM fact_sales f2 WHERE f2.product_id = fact_sales.product_id AND f2.sale_id <> fact_sales.sale_id);

-- ---------------------------------------------------------------------
-- ข้อ 10  Refresh Summary Table (เลือกได้ 1 วิธี — รันวิธี A ไว้ให้แล้ว)
-- ---------------------------------------------------------------------
-- วิธี A: Incremental refresh เฉพาะเดือนที่กระทบ (ใช้ transaction ให้ทำครบหรือไม่ทำเลย)
START TRANSACTION;
DELETE FROM summary_sales_month_product WHERE sales_month = '2025-03';
INSERT INTO summary_sales_month_product (sales_month, product_id, revenue, quantity, order_count, last_refreshed)
SELECT DATE_FORMAT(order_date, '%Y-%m'), product_id, SUM(amount), SUM(qty), COUNT(*), NOW()
FROM fact_sales
WHERE order_date >= '2025-03-01' AND order_date < '2025-04-01'
GROUP BY DATE_FORMAT(order_date, '%Y-%m'), product_id;
COMMIT;

-- วิธี B: Full refresh (ง่ายสุด ข้อมูลน้อยใช้ได้)
--   TRUNCATE TABLE summary_sales_month_product;
--   INSERT INTO summary_sales_month_product (sales_month, product_id, revenue, quantity, order_count, last_refreshed)
--   SELECT DATE_FORMAT(order_date,'%Y-%m'), product_id, SUM(amount), SUM(qty), COUNT(*), NOW()
--   FROM fact_sales GROUP BY DATE_FORMAT(order_date,'%Y-%m'), product_id;

-- วิธี C: Upsert (ไม่ต้องลบ ใช้ PK ชนแล้วอัปเดต)
--   INSERT INTO summary_sales_month_product (sales_month, product_id, revenue, quantity, order_count, last_refreshed)
--   SELECT DATE_FORMAT(order_date,'%Y-%m'), product_id, SUM(amount), SUM(qty), COUNT(*), NOW()
--   FROM fact_sales GROUP BY DATE_FORMAT(order_date,'%Y-%m'), product_id
--   ON DUPLICATE KEY UPDATE revenue = VALUES(revenue), quantity = VALUES(quantity),
--                           order_count = VALUES(order_count), last_refreshed = NOW();

-- วิธี D: อัตโนมัติด้วย Trigger (real-time แต่ทำให้ INSERT ช้าลง) — ดูไฟล์ week10_optional_trigger_event.sql
-- วิธี E: ตั้งเวลา EVENT รายคืน (batch) — ดูไฟล์เดียวกัน

-- Validation ซ้ำหลัง Refresh   Expected: Revenue 15566.00 | Quantity 56 | Order Count 31 -> ตรงกันทั้งหมด
SELECT 'Revenue' AS metric,
       (SELECT SUM(amount) FROM fact_sales) AS from_fact_sales,
       (SELECT SUM(revenue) FROM summary_sales_month_product) AS from_summary
UNION ALL
SELECT 'Quantity', (SELECT SUM(qty) FROM fact_sales), (SELECT SUM(quantity) FROM summary_sales_month_product)
UNION ALL
SELECT 'Order Count', (SELECT COUNT(*) FROM fact_sales), (SELECT SUM(order_count) FROM summary_sales_month_product);

SELECT * FROM summary_sales_month_product WHERE sales_month = '2025-03' ORDER BY product_id;
