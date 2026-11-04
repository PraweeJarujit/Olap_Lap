-- =====================================================================
-- Coast Café — เฉลยรวมทั้งแลป (Part A–D) + OLAP + Star Schema + Summary Table
-- ใช้กับ DuckDB (CLI / Desktop / Python)
--
-- วิธีรันแบบเร็ว (CLI):   duckdb coast_cafe.duckdb
--                         .read coast_cafe_all.sql
-- วิธีรันแบบได้ไฟล์ผลทุกข้อ:  python run_all.py   (ได้ output/*.csv + results.xlsx + RESULTS.md)
--
-- บรรทัด "-- @@ ชื่อ | คำอธิบาย" คือจุดแบ่งข้อ ให้ run_all.py ใช้ตั้งชื่อไฟล์ผลลัพธ์ ห้ามลบ
-- กติกาหลักของแลป: นับรายได้เฉพาะ status='Completed'
--                  net_sales = quantity * unit_price * (1 - discount_pct/100)
-- =====================================================================

-- @@ S0_setup | โหลด CSV + สร้าง fact_sales (VIEW เฉพาะ Completed)
CREATE OR REPLACE TABLE products  AS SELECT * FROM read_csv_auto('products.csv');
CREATE OR REPLACE TABLE customers AS SELECT * FROM read_csv_auto('customers.csv');
CREATE OR REPLACE TABLE orders    AS SELECT * FROM read_csv_auto('orders.csv');
CREATE OR REPLACE VIEW fact_sales AS
SELECT o.order_id, CAST(o.order_date AS DATE) AS order_date,
       o.customer_id, o.product_id, o.quantity, o.unit_price, o.discount_pct,
       o.channel,
       ROUND(o.quantity * o.unit_price * (1 - o.discount_pct/100.0), 2) AS net_sales
FROM orders o WHERE o.status = 'Completed';
SELECT (SELECT COUNT(*) FROM orders)     AS n_orders,
       (SELECT COUNT(*) FROM fact_sales) AS n_completed,
       (SELECT COUNT(*) FROM customers)  AS n_customers,
       (SELECT COUNT(*) FROM products)   AS n_products;

-- @@ S1_profile | สำรวจข้อมูล: ช่วงวันที่ / สถานะ / ช่องทาง
SELECT MIN(order_date) AS min_date, MAX(order_date) AS max_date,
       COUNT(DISTINCT order_id)    AS distinct_orders,
       COUNT(DISTINCT customer_id) AS distinct_customers,
       SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN status='Cancelled' THEN 1 ELSE 0 END) AS cancelled
FROM orders;

-- =====================================================================
-- PART A • SQL Review
-- =====================================================================

-- @@ A1 | SELECT/LIMIT: 10 แถวแรก
SELECT order_id, order_date, quantity, channel
FROM orders
LIMIT 10;

-- @@ A2 | WHERE/ORDER BY: Completed + ออนไลน์ เรียงวันที่ล่าสุด 10 แถว
SELECT order_id, order_date, customer_id, product_id, quantity, unit_price, channel, status
FROM orders
WHERE status = 'Completed' AND channel = 'ออนไลน์'
ORDER BY order_date DESC, order_id DESC
LIMIT 10;

-- @@ A3 | GROUP BY/COUNT: จำนวนสินค้าแยก category
SELECT category, COUNT(*) AS n_products
FROM products
GROUP BY category
ORDER BY n_products DESC, category;

-- @@ A4 | INNER JOIN: orders + products (ชื่อสินค้า จำนวน ราคาต่อหน่วย)
SELECT o.order_id, p.product_name, o.quantity, o.unit_price
FROM orders o
INNER JOIN products p ON o.product_id = p.product_id
ORDER BY o.order_id;

-- @@ A5 | JOIN+SUM: ยอดขายสุทธิตามจังหวัด มาก→น้อย
SELECT c.province,
       COUNT(*)                  AS n_orders,
       ROUND(SUM(f.net_sales),2) AS net_sales
FROM fact_sales f
JOIN customers c ON f.customer_id = c.customer_id
GROUP BY c.province
ORDER BY net_sales DESC;

-- @@ A6 | Aggregation: ยอดขายสุทธิแต่ละ category
SELECT p.category,
       COUNT(*)                  AS n_orders,
       SUM(f.quantity)           AS units,
       ROUND(SUM(f.net_sales),2) AS net_sales
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY net_sales DESC;

-- @@ A7 | TOP-N: ลูกค้า 5 รายยอดซื้อสะสมสูงสุด
SELECT c.customer_id, c.customer_name, c.province, c.segment,
       COUNT(*)                  AS n_orders,
       ROUND(SUM(f.net_sales),2) AS total_spent
FROM fact_sales f
JOIN customers c ON f.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.province, c.segment
ORDER BY total_spent DESC
LIMIT 5;

-- @@ A8 | HAVING: สินค้าที่ทำรายได้ > 2,000 บาท
SELECT p.product_id, p.product_name,
       ROUND(SUM(f.net_sales),2) AS net_sales
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING SUM(f.net_sales) > 2000
ORDER BY net_sales DESC;

-- =====================================================================
-- PART B • Modern Data Warehouse
-- =====================================================================

-- @@ B1_dims | Star Schema: สร้าง dim_date / dim_customer / dim_product / dim_channel
-- Grain ของ fact = 1 แถว ต่อ 1 order_id (ข้อมูลนี้ 1 ออเดอร์มีสินค้า 1 รายการ)
CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_key,
       CAST(d AS DATE)                        AS full_date,
       year(d)                                AS year,
       quarter(d)                             AS quarter,
       month(d)                               AS month_no,
       strftime(d, '%Y-%m')                   AS month,
       dayofweek(d)                           AS day_of_week,   -- 0=อาทิตย์
       strftime(d, '%a')                      AS day_name,
       CASE WHEN dayofweek(d) IN (0,6) THEN 'Weekend' ELSE 'Weekday' END AS day_type
FROM generate_series(DATE '2026-07-01', DATE '2026-09-30', INTERVAL 1 DAY) t(d);

CREATE OR REPLACE TABLE dim_customer AS
SELECT ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
       customer_id, customer_name, province, segment
FROM customers;

CREATE OR REPLACE TABLE dim_product AS
SELECT ROW_NUMBER() OVER (ORDER BY product_id) AS product_key,
       product_id, product_name, category, list_price, unit_cost
FROM products;

CREATE OR REPLACE TABLE dim_channel AS
SELECT ROW_NUMBER() OVER (ORDER BY channel) AS channel_key, channel
FROM (SELECT DISTINCT channel FROM orders);

SELECT 'dim_date' AS tbl, COUNT(*) AS n_rows FROM dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_product',  COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_channel',  COUNT(*) FROM dim_channel;

-- @@ B1_fact | Star Schema: fact_sales_star (FK = surrogate keys, measures = qty / gross / discount / net / cost / profit)
CREATE OR REPLACE TABLE fact_sales_star AS
SELECT o.order_id,                                         -- degenerate dimension
       CAST(strftime(CAST(o.order_date AS DATE), '%Y%m%d') AS INTEGER) AS date_key,
       dc.customer_key, dp.product_key, ch.channel_key,
       o.quantity,
       o.unit_price,
       o.discount_pct,
       ROUND(o.quantity * o.unit_price, 2)                              AS gross_sales,
       ROUND(o.quantity * o.unit_price * o.discount_pct/100.0, 2)       AS discount_amount,
       ROUND(o.quantity * o.unit_price * (1 - o.discount_pct/100.0), 2) AS net_sales,
       o.quantity * dp.unit_cost                                         AS total_cost,
       ROUND(o.quantity * o.unit_price * (1 - o.discount_pct/100.0) - o.quantity * dp.unit_cost, 2) AS gross_profit
FROM orders o
JOIN dim_customer dc ON o.customer_id = dc.customer_id
JOIN dim_product  dp ON o.product_id  = dp.product_id
JOIN dim_channel  ch ON o.channel     = ch.channel
WHERE o.status = 'Completed';

-- ตรวจ: ก่อน/หลัง JOIN มิติ ต้องได้จำนวนแถวและยอดเท่ากัน (ถ้าไม่เท่า = FK หาย หรือ key ซ้ำในมิติ)
SELECT 'fact_sales (view เดิม)' AS source, COUNT(*) AS n_rows, ROUND(SUM(net_sales),2) AS net_sales FROM fact_sales
UNION ALL
SELECT 'fact_sales_star', COUNT(*), ROUND(SUM(net_sales),2) FROM fact_sales_star;

-- @@ B1_view | VIEW ที่ JOIN Star Schema ครบ (ใช้ต่อในงาน OLAP)
CREATE OR REPLACE VIEW v_sales AS
SELECT f.order_id, d.full_date, d.year, d.quarter, d.month, d.day_name, d.day_type,
       c.customer_id, c.customer_name, c.province, c.segment,
       p.product_id, p.product_name, p.category,
       ch.channel,
       f.quantity, f.unit_price, f.discount_pct,
       f.gross_sales, f.discount_amount, f.net_sales, f.total_cost, f.gross_profit
FROM fact_sales_star f
JOIN dim_date     d  ON f.date_key     = d.date_key
JOIN dim_customer c  ON f.customer_key = c.customer_key
JOIN dim_product  p  ON f.product_key  = p.product_key
JOIN dim_channel  ch ON f.channel_key  = ch.channel_key;
SELECT * FROM v_sales ORDER BY order_id LIMIT 10;

-- @@ B2 | Data Mart: VIEW mart_monthly_sales (เดือน × category × channel)
CREATE OR REPLACE VIEW mart_monthly_sales AS
SELECT DATE_TRUNC('month', f.order_date) AS month,
       p.category,
       f.channel,
       COUNT(*)                     AS n_orders,
       SUM(f.quantity)              AS units,
       ROUND(SUM(f.net_sales), 2)   AS revenue
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY DATE_TRUNC('month', f.order_date), p.category, f.channel;

SELECT * FROM mart_monthly_sales ORDER BY month, category, channel;

-- @@ B2_check | ตรวจ Data Mart: ยอดรวมใน mart ต้องเท่ากับ fact
SELECT (SELECT ROUND(SUM(revenue),2) FROM mart_monthly_sales) AS mart_total,
       (SELECT ROUND(SUM(net_sales),2) FROM fact_sales)       AS fact_total,
       (SELECT SUM(n_orders) FROM mart_monthly_sales)         AS mart_orders,
       (SELECT COUNT(*) FROM fact_sales)                      AS fact_orders;

-- @@ B3_quality | Data Quality: 3 ประเด็นหลัก + ข้อเพิ่มเติม (นับจำนวนที่ผิด)
SELECT 'customer_id หาย (NULL/ว่าง)' AS check_name, COUNT(*) AS n_bad
FROM orders WHERE customer_id IS NULL OR TRIM(CAST(customer_id AS VARCHAR)) = ''
UNION ALL
SELECT 'customer_id ไม่พบใน customers', COUNT(*)
FROM orders o WHERE customer_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o.customer_id)
UNION ALL
SELECT 'quantity ไม่สมเหตุสมผล (NULL, <=0, >20)', COUNT(*)
FROM orders WHERE quantity IS NULL OR quantity <= 0 OR quantity > 20
UNION ALL
SELECT 'product_id ไม่พบใน products', COUNT(*)
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = o.product_id)
UNION ALL
SELECT 'order_id ซ้ำ', COUNT(*) - COUNT(DISTINCT order_id) FROM orders
UNION ALL
SELECT 'discount_pct นอกช่วง 0-100', COUNT(*)
FROM orders WHERE discount_pct < 0 OR discount_pct > 100
UNION ALL
SELECT 'unit_price ไม่ตรง list_price', COUNT(*)
FROM orders o JOIN products p ON o.product_id = p.product_id
WHERE o.unit_price <> p.list_price
UNION ALL
SELECT 'status นอกเหนือ Completed/Cancelled', COUNT(*)
FROM orders WHERE status NOT IN ('Completed','Cancelled')
UNION ALL
SELECT 'order_date นอกช่วง ก.ค.-ก.ย. 2026', COUNT(*)
FROM orders WHERE CAST(order_date AS DATE) NOT BETWEEN DATE '2026-07-01' AND DATE '2026-09-30';

-- @@ B3_detail | Data Quality: แสดงแถวที่มีปัญหา (ถ้าว่าง = ข้อมูลสะอาด)
SELECT o.*,
       CASE WHEN o.customer_id IS NULL THEN 'missing customer_id'
            WHEN c.customer_id IS NULL THEN 'unknown customer_id'
            WHEN p.product_id  IS NULL THEN 'unknown product_id'
            ELSE 'bad quantity' END AS issue
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN products  p ON o.product_id  = p.product_id
WHERE o.customer_id IS NULL OR c.customer_id IS NULL OR p.product_id IS NULL
   OR o.quantity IS NULL OR o.quantity <= 0 OR o.quantity > 20;

-- @@ B3_test | ทดลองฉีดข้อมูลเสีย 3 แถว (ใน temp table) เพื่อพิสูจน์ว่า SQL ตรวจจับได้จริง
CREATE OR REPLACE TEMP TABLE orders_test AS
SELECT * FROM orders
UNION ALL SELECT 'X0001', DATE '2026-09-01', NULL,  'P01', 2,  65, 0, 'หน้าร้าน', 'Completed'
UNION ALL SELECT 'X0002', DATE '2026-09-01', 'C001', 'P01', -3, 65, 0, 'หน้าร้าน', 'Completed'
UNION ALL SELECT 'X0003', DATE '2026-09-01', 'C001', 'P99', 1,  50, 0, 'หน้าร้าน', 'Completed';
SELECT o.order_id, o.customer_id, o.product_id, o.quantity,
       CASE WHEN o.customer_id IS NULL                 THEN 'missing customer_id → ส่งไป reject / ใส่ Unknown member (customer_key=-1)'
            WHEN c.customer_id IS NULL                 THEN 'unknown customer_id → reject หรือเพิ่มใน dim'
            WHEN p.product_id  IS NULL                 THEN 'unknown product_id → reject, แจ้งเจ้าของ product master'
            WHEN o.quantity IS NULL OR o.quantity <= 0 THEN 'quantity <= 0 → reject / ตรวจว่าเป็นการคืนสินค้าหรือไม่'
            ELSE 'quantity สูงผิดปกติ → flag ตรวจสอบ' END AS issue_and_action
FROM orders_test o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN products  p ON o.product_id  = p.product_id
WHERE o.customer_id IS NULL OR c.customer_id IS NULL OR p.product_id IS NULL
   OR o.quantity IS NULL OR o.quantity <= 0 OR o.quantity > 20;

-- =====================================================================
-- PART C • AI Analytics (Features)
-- =====================================================================

-- @@ C1 | ยอดขายรายวัน + Moving Average 7 แถว (ROWS)
WITH daily AS (
    SELECT order_date, COUNT(*) AS n_orders, ROUND(SUM(net_sales),2) AS daily_sales
    FROM fact_sales
    GROUP BY order_date
)
SELECT order_date, n_orders, daily_sales,
       ROUND(AVG(daily_sales) OVER (ORDER BY order_date
                                    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS ma7_rows
FROM daily
ORDER BY order_date;

-- @@ C1_calendar | MA 7 วันจริง: เติมวันที่ไม่มีขายเป็น 0 ด้วย date spine แล้วเทียบกับแบบ 7 แถว
WITH spine AS (
    SELECT CAST(d AS DATE) AS order_date
    FROM generate_series((SELECT MIN(order_date) FROM fact_sales),
                         (SELECT MAX(order_date) FROM fact_sales), INTERVAL 1 DAY) t(d)
), daily AS (
    SELECT order_date, SUM(net_sales) AS s FROM fact_sales GROUP BY order_date
), filled AS (
    SELECT sp.order_date, COALESCE(d.s, 0) AS daily_sales, (d.s IS NULL) AS no_sales_day
    FROM spine sp LEFT JOIN daily d USING (order_date)
)
SELECT order_date, ROUND(daily_sales,2) AS daily_sales, no_sales_day,
       ROUND(AVG(daily_sales) OVER (ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS ma7_true_days
FROM filled
ORDER BY order_date;

-- @@ C1_gaps | นับวันที่ไม่มียอดขาย (เหตุผลที่ 7 แถว ≠ 7 วัน)
SELECT COUNT(*) AS days_in_period,
       COUNT(d.order_date) AS days_with_sales,
       COUNT(*) - COUNT(d.order_date) AS days_without_sales
FROM generate_series(DATE '2026-07-01', DATE '2026-09-30', INTERVAL 1 DAY) t(x)
LEFT JOIN (SELECT DISTINCT order_date FROM fact_sales) d ON d.order_date = CAST(t.x AS DATE);

-- @@ C2 | Customer Features (RFM): last_order, frequency, monetary + recency/score
WITH base AS (
    SELECT customer_id,
           MAX(order_date)            AS last_order,
           COUNT(DISTINCT order_id)   AS frequency,
           ROUND(SUM(net_sales), 2)   AS monetary,
           ROUND(AVG(net_sales), 2)   AS avg_order_value
    FROM fact_sales
    GROUP BY customer_id
), scored AS (
    SELECT b.*,
           DATE_DIFF('day', b.last_order, DATE '2026-10-01') AS recency_days,   -- วันอ้างอิง = วันถัดจากวันสุดท้ายของข้อมูล
           NTILE(3) OVER (ORDER BY DATE_DIFF('day', b.last_order, DATE '2026-10-01') DESC) AS r_score,  -- 3 = ซื้อล่าสุด
           NTILE(3) OVER (ORDER BY b.frequency) AS f_score,
           NTILE(3) OVER (ORDER BY b.monetary)  AS m_score
    FROM base b
)
SELECT s.*, c.province, c.segment,
       r_score + f_score + m_score AS rfm_total,
       CASE WHEN r_score + f_score + m_score >= 8 THEN 'Champion'
            WHEN r_score + f_score + m_score >= 6 THEN 'Loyal'
            WHEN r_score = 1                      THEN 'At risk'
            ELSE 'Regular' END AS rfm_segment
FROM scored s JOIN customers c USING (customer_id)
ORDER BY monetary DESC;

-- @@ C2_segment_summary | สรุปกลุ่ม RFM (ใช้ตอบว่า "ลูกค้ากลุ่มใดควรได้แคมเปญ")
WITH base AS (
    SELECT customer_id, MAX(order_date) AS last_order,
           COUNT(*) AS frequency, SUM(net_sales) AS monetary
    FROM fact_sales GROUP BY customer_id
), scored AS (
    SELECT *, NTILE(3) OVER (ORDER BY last_order) AS r_score,
              NTILE(3) OVER (ORDER BY frequency)  AS f_score,
              NTILE(3) OVER (ORDER BY monetary)   AS m_score
    FROM base
)
SELECT CASE WHEN r_score+f_score+m_score >= 8 THEN 'Champion'
            WHEN r_score+f_score+m_score >= 6 THEN 'Loyal'
            WHEN r_score = 1 THEN 'At risk' ELSE 'Regular' END AS rfm_segment,
       COUNT(*) AS n_customers, ROUND(AVG(frequency),2) AS avg_freq,
       ROUND(AVG(monetary),2) AS avg_monetary, ROUND(SUM(monetary),2) AS total_monetary
FROM scored GROUP BY 1 ORDER BY total_monetary DESC;

-- @@ C3_feature_table | ตารางฟีเจอร์รายวันสำหรับพยากรณ์ยอดขาย (กัน data leakage: ใช้เฉพาะข้อมูลอดีต)
WITH spine AS (
    SELECT CAST(d AS DATE) AS order_date
    FROM generate_series(DATE '2026-07-01', DATE '2026-09-30', INTERVAL 1 DAY) t(d)
), daily AS (
    SELECT order_date, SUM(net_sales) AS s FROM fact_sales GROUP BY order_date
), f AS (
    SELECT sp.order_date, COALESCE(d.s,0) AS y_sales FROM spine sp LEFT JOIN daily d USING(order_date)
)
SELECT order_date,
       ROUND(y_sales,2)                                                         AS target_sales_today,
       dayofweek(order_date)                                                    AS dow,
       CASE WHEN dayofweek(order_date) IN (0,6) THEN 1 ELSE 0 END               AS is_weekend,
       ROUND(LAG(y_sales,1) OVER w, 2)                                           AS lag_1,
       ROUND(LAG(y_sales,7) OVER w, 2)                                           AS lag_7,
       ROUND(AVG(y_sales) OVER (ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING), 2) AS ma7_past_only,
       CASE WHEN order_date < DATE '2026-09-01' THEN 'train' ELSE 'test' END    AS split   -- แบ่งตามเวลา ไม่สุ่ม
FROM f
WINDOW w AS (ORDER BY order_date)
ORDER BY order_date;

-- =====================================================================
-- PART D • ตัวเลขสำหรับ Executive Insight
-- =====================================================================

-- @@ D1_channel | ช่องทางใดทำรายได้ดีที่สุด (+ AOV, % share, อัตรายกเลิก)
SELECT o.channel,
       COUNT(*) FILTER (WHERE o.status='Completed') AS completed_orders,
       COUNT(*) FILTER (WHERE o.status='Cancelled') AS cancelled_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.status='Cancelled') / COUNT(*), 1) AS cancel_rate_pct,
       ROUND(SUM(CASE WHEN o.status='Completed' THEN o.quantity*o.unit_price*(1-o.discount_pct/100.0) END),2) AS net_sales,
       ROUND(SUM(CASE WHEN o.status='Completed' THEN o.quantity*o.unit_price*(1-o.discount_pct/100.0) END)
             / COUNT(*) FILTER (WHERE o.status='Completed'), 2) AS aov,
       ROUND(100.0 * SUM(CASE WHEN o.status='Completed' THEN o.quantity*o.unit_price*(1-o.discount_pct/100.0) END)
             / SUM(SUM(CASE WHEN o.status='Completed' THEN o.quantity*o.unit_price*(1-o.discount_pct/100.0) END)) OVER (), 1) AS share_pct
FROM orders o
GROUP BY o.channel
ORDER BY net_sales DESC;

-- @@ D2_product_profit | สินค้าใดควรผลักดัน: ยอดขาย + กำไรขั้นต้น + margin
SELECT p.product_id, p.product_name, p.category,
       SUM(f.quantity)                                        AS units,
       ROUND(SUM(f.net_sales),2)                              AS net_sales,
       SUM(f.quantity * p.unit_cost)                          AS cost,
       ROUND(SUM(f.net_sales) - SUM(f.quantity*p.unit_cost),2) AS gross_profit,
       ROUND(100.0*(SUM(f.net_sales) - SUM(f.quantity*p.unit_cost)) / SUM(f.net_sales),1) AS margin_pct,
       RANK() OVER (ORDER BY SUM(f.net_sales) - SUM(f.quantity*p.unit_cost) DESC) AS profit_rank
FROM fact_sales f JOIN products p USING (product_id)
GROUP BY p.product_id, p.product_name, p.category
ORDER BY gross_profit DESC;

-- @@ D3_segment | Member vs Walk-in
SELECT c.segment,
       COUNT(DISTINCT c.customer_id)  AS n_customers,
       COUNT(*)                       AS n_orders,
       ROUND(SUM(f.net_sales),2)      AS net_sales,
       ROUND(SUM(f.net_sales)/COUNT(*),2) AS aov,
       ROUND(1.0*COUNT(*)/COUNT(DISTINCT c.customer_id),2) AS orders_per_customer
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY c.segment ORDER BY net_sales DESC;

-- @@ D4_kpi | KPI ภาพรวม
SELECT COUNT(*)                                AS completed_orders,
       COUNT(DISTINCT customer_id)             AS active_customers,
       SUM(quantity)                           AS units,
       ROUND(SUM(quantity*unit_price),2)       AS gross_sales,
       ROUND(SUM(quantity*unit_price) - SUM(net_sales),2) AS total_discount,
       ROUND(SUM(net_sales),2)                 AS net_sales,
       ROUND(SUM(net_sales)/COUNT(DISTINCT order_id),2) AS aov,
       ROUND(AVG(net_sales),2)                 AS avg_line
FROM fact_sales;

-- @@ D5_month_growth | ยอดรายเดือน + % เปลี่ยนแปลงเดือนต่อเดือน (LAG)
WITH m AS (
    SELECT strftime(order_date, '%Y-%m') AS month, ROUND(SUM(net_sales),2) AS net_sales, COUNT(*) AS n_orders
    FROM fact_sales GROUP BY 1
)
SELECT month, n_orders, net_sales,
       LAG(net_sales) OVER (ORDER BY month) AS prev_month,
       ROUND(100.0*(net_sales - LAG(net_sales) OVER (ORDER BY month)) / LAG(net_sales) OVER (ORDER BY month), 1) AS mom_pct
FROM m ORDER BY month;

-- =====================================================================
-- OLAP OPERATIONS บนข้อมูล Coast Café (สไลด์ OLAP)
-- =====================================================================

-- @@ O1_rollup | Roll-up: ยอดรายเดือน
SELECT strftime(order_date,'%Y-%m') AS month, ROUND(SUM(net_sales),2) AS revenue
FROM fact_sales GROUP BY month ORDER BY month;

-- @@ O2_drilldown | Drill-down: เดือน × จังหวัด
SELECT strftime(f.order_date,'%Y-%m') AS month, c.province, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY month, c.province ORDER BY month, c.province;

-- @@ O3_drilldown_day | Drill-down ในมิติเวลา: รายวันเฉพาะกันยายน
SELECT order_date, ROUND(SUM(net_sales),2) AS revenue
FROM fact_sales WHERE strftime(order_date,'%Y-%m') = '2026-09'
GROUP BY order_date ORDER BY order_date;

-- @@ O4_slice | Slice: เฉพาะกันยายน แยกจังหวัด
SELECT c.province, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
WHERE strftime(f.order_date,'%Y-%m') = '2026-09'
GROUP BY c.province ORDER BY revenue DESC;

-- @@ O5_dice | Dice: กันยายน + เครื่องดื่ม + ชลบุรี/ระยอง
SELECT c.province, f.channel, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f
JOIN customers c USING (customer_id)
JOIN products  p USING (product_id)
WHERE strftime(f.order_date,'%Y-%m') = '2026-09'
  AND p.category = 'เครื่องดื่ม'
  AND c.province IN ('ชลบุรี','ระยอง')
GROUP BY c.province, f.channel ORDER BY c.province, revenue DESC;

-- @@ O6_having | WHERE vs HAVING: จังหวัดที่ยอดกันยายน > 3,000
SELECT c.province, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
WHERE strftime(f.order_date,'%Y-%m') = '2026-09'     -- กรองแถว (ก่อนรวม)
GROUP BY c.province
HAVING SUM(f.net_sales) > 3000                        -- กรองกลุ่ม (หลังรวม)
ORDER BY revenue DESC;

-- @@ O7_drillthrough | Drill-through: รายการต้นทางของ ชลบุรี กันยายน
SELECT f.order_id, f.order_date, c.customer_id, p.product_name, f.quantity, f.unit_price, f.discount_pct, f.net_sales
FROM fact_sales f JOIN customers c USING (customer_id) JOIN products p USING (product_id)
WHERE c.province = 'ชลบุรี' AND strftime(f.order_date,'%Y-%m') = '2026-09'
ORDER BY f.order_date, f.order_id;

-- @@ O8_pivot_case | Pivot ด้วย SUM(CASE): จังหวัด × เดือน
SELECT c.province,
       ROUND(SUM(CASE WHEN strftime(f.order_date,'%Y-%m')='2026-07' THEN f.net_sales ELSE 0 END),2) AS jul,
       ROUND(SUM(CASE WHEN strftime(f.order_date,'%Y-%m')='2026-08' THEN f.net_sales ELSE 0 END),2) AS aug,
       ROUND(SUM(CASE WHEN strftime(f.order_date,'%Y-%m')='2026-09' THEN f.net_sales ELSE 0 END),2) AS sep,
       ROUND(SUM(f.net_sales),2) AS total
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY c.province ORDER BY total DESC;

-- @@ O9_pivot_duckdb | Pivot ด้วยคำสั่ง PIVOT ของ DuckDB: category × channel
SELECT * FROM (
    PIVOT (SELECT p.category, f.channel, f.net_sales
           FROM fact_sales f JOIN products p USING (product_id))
    ON channel USING ROUND(SUM(net_sales),2)
    GROUP BY category
) ORDER BY category;

-- @@ O10_union_total | Subtotal + Grand total ด้วย UNION ALL
SELECT * FROM (
    SELECT strftime(order_date,'%Y-%m') AS month, ROUND(SUM(net_sales),2) AS revenue
    FROM fact_sales GROUP BY 1
    UNION ALL
    SELECT 'ALL', ROUND(SUM(net_sales),2) FROM fact_sales
) ORDER BY CASE WHEN month='ALL' THEN 1 ELSE 0 END, month;

-- @@ O11_rollup_op | GROUP BY ROLLUP: subtotal ตามลำดับชั้น category → product (+ grand total)
SELECT COALESCE(p.category, '== GRAND TOTAL ==') AS category,
       COALESCE(p.product_name, CASE WHEN p.category IS NOT NULL THEN '-- subtotal --' END) AS product_name,
       ROUND(SUM(f.net_sales),2) AS revenue,
       GROUPING(p.category, p.product_name) AS grouping_level
FROM fact_sales f JOIN products p USING (product_id)
GROUP BY ROLLUP (p.category, p.product_name)
ORDER BY p.category NULLS LAST, grouping_level, revenue DESC;

-- @@ O12_cube | GROUP BY CUBE: ทุกการรวมของ province × channel
SELECT COALESCE(c.province,'(ทุกจังหวัด)') AS province,
       COALESCE(f.channel,'(ทุกช่องทาง)')  AS channel,
       ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY CUBE (c.province, f.channel)
ORDER BY c.province NULLS LAST, f.channel NULLS LAST;

-- @@ O13_rank_in_group | Window: อันดับสินค้าในแต่ละ category (QUALIFY)
WITH ps AS (
    SELECT p.category, p.product_name, SUM(f.net_sales) AS revenue
    FROM fact_sales f JOIN products p USING (product_id)
    GROUP BY p.category, p.product_name
)
SELECT category, product_name, ROUND(revenue,2) AS revenue,
       RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category,
       ROUND(100.0*revenue/SUM(revenue) OVER (PARTITION BY category),1) AS pct_of_category
FROM ps
ORDER BY category, rank_in_category;

-- @@ O14_top_per_group | Top-1 category ของแต่ละจังหวัด (Aggregate ก่อน แล้ว ROW_NUMBER)
WITH pc AS (
    SELECT c.province, p.category, SUM(f.net_sales) AS revenue
    FROM fact_sales f JOIN customers c USING (customer_id) JOIN products p USING (product_id)
    GROUP BY c.province, p.category
)
SELECT province, category, ROUND(revenue,2) AS revenue
FROM pc
QUALIFY ROW_NUMBER() OVER (PARTITION BY province ORDER BY revenue DESC) = 1
ORDER BY revenue DESC;

-- @@ O15_aov | AOV vs AVG(line) และการนับออเดอร์ (Grain)
SELECT ROUND(SUM(net_sales),2)                       AS revenue,
       COUNT(*)                                      AS line_count,
       COUNT(DISTINCT order_id)                      AS order_count,
       SUM(quantity)                                 AS units,
       ROUND(SUM(net_sales)/COUNT(DISTINCT order_id),2) AS aov,
       ROUND(AVG(net_sales),2)                       AS avg_line
FROM fact_sales;

-- @@ O16_cumulative | ยอดสะสม (running total) รายวัน
WITH d AS (SELECT order_date, SUM(net_sales) AS s FROM fact_sales GROUP BY 1)
SELECT order_date, ROUND(s,2) AS daily_sales,
       ROUND(SUM(s) OVER (ORDER BY order_date),2) AS running_total,
       ROUND(SUM(s) OVER (PARTITION BY strftime(order_date,'%Y-%m') ORDER BY order_date),2) AS month_to_date
FROM d ORDER BY order_date;

-- @@ O17_weekday | ยอดตามวันในสัปดาห์ (ใช้ dim_date)
SELECT d.day_of_week, d.day_name, d.day_type, COUNT(f.order_id) AS n_orders, ROUND(COALESCE(SUM(f.net_sales),0),2) AS revenue
FROM dim_date d LEFT JOIN fact_sales_star f ON f.date_key = d.date_key
GROUP BY d.day_of_week, d.day_name, d.day_type
ORDER BY d.day_of_week;

-- =====================================================================
-- SUMMARY / AGGREGATE TABLE (แนวแลปสัปดาห์ 10) บน Coast Café
-- =====================================================================

-- @@ T1_baseline | Baseline: เดือน × สินค้า จาก fact
SELECT strftime(order_date,'%Y-%m') AS sales_month, product_id,
       ROUND(SUM(net_sales),2) AS revenue, SUM(quantity) AS quantity, COUNT(*) AS order_count
FROM fact_sales
GROUP BY sales_month, product_id
ORDER BY sales_month, product_id;

-- @@ T2_create_summary | สร้าง Summary Table (Grain = 1 เดือน × 1 สินค้า, PK = (sales_month, product_id))
CREATE OR REPLACE TABLE summary_month_product (
    sales_month    VARCHAR NOT NULL,
    product_id     VARCHAR NOT NULL,
    revenue        DECIMAL(12,2),
    quantity       INTEGER,
    order_count    INTEGER,
    last_refreshed TIMESTAMP,
    PRIMARY KEY (sales_month, product_id)
);
INSERT INTO summary_month_product
SELECT strftime(order_date,'%Y-%m'), product_id,
       ROUND(SUM(net_sales),2), SUM(quantity), COUNT(*), now()
FROM fact_sales GROUP BY 1, 2;
SELECT sales_month, product_id, revenue, quantity, order_count
FROM summary_month_product ORDER BY sales_month, product_id;

-- @@ T3_validate | Validation: fact vs summary
SELECT 'revenue' AS metric, (SELECT ROUND(SUM(net_sales),2) FROM fact_sales) AS from_fact,
       (SELECT SUM(revenue) FROM summary_month_product) AS from_summary
UNION ALL SELECT 'quantity', (SELECT SUM(quantity) FROM fact_sales), (SELECT SUM(quantity) FROM summary_month_product)
UNION ALL SELECT 'order_count', (SELECT COUNT(*) FROM fact_sales), (SELECT SUM(order_count) FROM summary_month_product);

-- @@ T4_explain | EXPLAIN: fact vs summary (ดูจำนวนแถวที่ scan)
EXPLAIN SELECT strftime(order_date,'%Y-%m'), product_id, SUM(net_sales) FROM fact_sales GROUP BY 1,2;

-- @@ T5_stale | Data Stale: เพิ่มออเดอร์ใหม่ใน orders แล้ว summary ไม่เปลี่ยน (เพราะเป็นตารางที่คำนวณไว้ล่วงหน้า)
INSERT INTO orders VALUES ('O9999', DATE '2026-09-30', 'C001', 'P01', 10, 65, 0, 'หน้าร้าน', 'Completed');
SELECT 'fact (สด)' AS source, ROUND(SUM(net_sales),2) AS revenue_sep_p01 FROM fact_sales
 WHERE strftime(order_date,'%Y-%m')='2026-09' AND product_id='P01'
UNION ALL
SELECT 'summary (เก่า)', revenue FROM summary_month_product WHERE sales_month='2026-09' AND product_id='P01';

-- @@ T6_refresh | Refresh แบบ incremental: ลบเฉพาะเดือนที่กระทบ แล้วคำนวณใหม่ + ตรวจซ้ำ
DELETE FROM summary_month_product WHERE sales_month = '2026-09';
INSERT INTO summary_month_product
SELECT strftime(order_date,'%Y-%m'), product_id, ROUND(SUM(net_sales),2), SUM(quantity), COUNT(*), now()
FROM fact_sales WHERE strftime(order_date,'%Y-%m') = '2026-09' GROUP BY 1, 2;
SELECT 'revenue' AS metric, (SELECT ROUND(SUM(net_sales),2) FROM fact_sales) AS from_fact,
       (SELECT SUM(revenue) FROM summary_month_product) AS from_summary,
       (SELECT ROUND(SUM(net_sales),2) FROM fact_sales) = (SELECT SUM(revenue) FROM summary_month_product) AS is_match;

-- @@ T7_cleanup | ลบออเดอร์ทดลอง O9999 คืนข้อมูลเดิม แล้ว refresh เต็ม (full refresh)
DELETE FROM orders WHERE order_id = 'O9999';
DELETE FROM summary_month_product;
INSERT INTO summary_month_product
SELECT strftime(order_date,'%Y-%m'), product_id, ROUND(SUM(net_sales),2), SUM(quantity), COUNT(*), now()
FROM fact_sales GROUP BY 1, 2;
SELECT COUNT(*) AS orders_rows, (SELECT SUM(revenue) FROM summary_month_product) AS summary_total FROM orders;

-- =====================================================================
-- OLTP vs OLAP (สไลด์ 5): guarded UPDATE ในธุรกรรม
-- =====================================================================

-- @@ X1_oltp | OLTP: เปลี่ยนสถานะออเดอร์เดียวแบบมีเงื่อนไข (รันซ้ำจะไม่กระทบแถวไหน)
CREATE OR REPLACE TEMP TABLE oltp_orders AS SELECT 'O1004' AS order_id, 'PENDING' AS status;
BEGIN TRANSACTION;
UPDATE oltp_orders SET status = 'PAID' WHERE order_id = 'O1004' AND status = 'PENDING';
COMMIT;
SELECT * FROM oltp_orders;

-- @@ X2_export_note | ส่งออกผลเป็น CSV (CLI) — ตัวอย่าง
-- COPY (SELECT * FROM mart_monthly_sales ORDER BY month) TO 'mart_monthly_sales.csv' (HEADER, DELIMITER ',');
SELECT 'ใช้ COPY (...) TO ''file.csv'' (HEADER) เพื่อส่งออกผล' AS note;
