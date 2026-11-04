# ผลลัพธ์ทั้งหมดจาก coast_cafe_all.sql

## S0_setup — โหลด CSV + สร้าง fact_sales (VIEW เฉพาะ Completed)

```sql
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
```

| n_orders | n_completed | n_customers | n_products |
|---|---|---|---|
| 240 | 225 | 40 | 8 |


## S1_profile — สำรวจข้อมูล: ช่วงวันที่ / สถานะ / ช่องทาง

```sql
SELECT MIN(order_date) AS min_date, MAX(order_date) AS max_date,
       COUNT(DISTINCT order_id)    AS distinct_orders,
       COUNT(DISTINCT customer_id) AS distinct_customers,
       SUM(CASE WHEN status='Completed' THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN status='Cancelled' THEN 1 ELSE 0 END) AS cancelled
FROM orders;

-- =====================================================================
-- PART A • SQL Review
-- =====================================================================
```

| min_date | max_date | distinct_orders | distinct_customers | completed | cancelled |
|---|---|---|---|---|---|
| 2026-07-01 00:00:00 | 2026-09-30 00:00:00 | 240 | 40 | 225.0 | 15.0 |


## A1 — SELECT/LIMIT: 10 แถวแรก

```sql
SELECT order_id, order_date, quantity, channel
FROM orders
LIMIT 10;
```

| order_id | order_date | quantity | channel |
|---|---|---|---|
| O0001 | 2026-09-10 00:00:00 | 3 | เดลิเวอรี |
| O0002 | 2026-08-26 00:00:00 | 2 | เดลิเวอรี |
| O0003 | 2026-07-09 00:00:00 | 3 | หน้าร้าน |
| O0004 | 2026-07-19 00:00:00 | 1 | หน้าร้าน |
| O0005 | 2026-07-11 00:00:00 | 1 | ออนไลน์ |
| O0006 | 2026-08-04 00:00:00 | 1 | เดลิเวอรี |
| O0007 | 2026-09-01 00:00:00 | 2 | เดลิเวอรี |
| O0008 | 2026-09-27 00:00:00 | 4 | ออนไลน์ |
| O0009 | 2026-09-14 00:00:00 | 4 | เดลิเวอรี |
| O0010 | 2026-07-26 00:00:00 | 1 | เดลิเวอรี |


## A2 — WHERE/ORDER BY: Completed + ออนไลน์ เรียงวันที่ล่าสุด 10 แถว

```sql
SELECT order_id, order_date, customer_id, product_id, quantity, unit_price, channel, status
FROM orders
WHERE status = 'Completed' AND channel = 'ออนไลน์'
ORDER BY order_date DESC, order_id DESC
LIMIT 10;
```

| order_id | order_date | customer_id | product_id | quantity | unit_price | channel | status |
|---|---|---|---|---|---|---|---|
| O0092 | 2026-09-29 00:00:00 | C020 | P04 | 4 | 89 | ออนไลน์ | Completed |
| O0106 | 2026-09-27 00:00:00 | C026 | P04 | 2 | 89 | ออนไลน์ | Completed |
| O0008 | 2026-09-27 00:00:00 | C006 | P05 | 4 | 70 | ออนไลน์ | Completed |
| O0141 | 2026-09-26 00:00:00 | C040 | P01 | 3 | 65 | ออนไลน์ | Completed |
| O0239 | 2026-09-21 00:00:00 | C007 | P03 | 4 | 75 | ออนไลน์ | Completed |
| O0193 | 2026-09-20 00:00:00 | C026 | P06 | 1 | 99 | ออนไลน์ | Completed |
| O0174 | 2026-09-20 00:00:00 | C039 | P03 | 4 | 75 | ออนไลน์ | Completed |
| O0064 | 2026-09-20 00:00:00 | C026 | P07 | 1 | 119 | ออนไลน์ | Completed |
| O0029 | 2026-09-19 00:00:00 | C026 | P01 | 3 | 65 | ออนไลน์ | Completed |
| O0163 | 2026-09-17 00:00:00 | C039 | P08 | 4 | 20 | ออนไลน์ | Completed |


## A3 — GROUP BY/COUNT: จำนวนสินค้าแยก category

```sql
SELECT category, COUNT(*) AS n_products
FROM products
GROUP BY category
ORDER BY n_products DESC, category;
```

| category | n_products |
|---|---|
| เครื่องดื่ม | 4 |
| อาหาร | 2 |
| เบเกอรี | 2 |


## A4 — INNER JOIN: orders + products (ชื่อสินค้า จำนวน ราคาต่อหน่วย)

```sql
SELECT o.order_id, p.product_name, o.quantity, o.unit_price
FROM orders o
INNER JOIN products p ON o.product_id = p.product_id
ORDER BY o.order_id;
```

| order_id | product_name | quantity | unit_price |
|---|---|---|---|
| O0001 | กาแฟเย็น | 3 | 65 |
| O0002 | โกโก้ | 2 | 70 |
| O0003 | โกโก้ | 3 | 70 |
| O0004 | น้ำเปล่า | 1 | 20 |
| O0005 | แซนด์วิช | 1 | 89 |
| O0006 | เค้กช็อกโกแลต | 1 | 99 |
| O0007 | ครัวซองต์ | 2 | 75 |
| O0008 | โกโก้ | 4 | 70 |
| O0009 | โกโก้ | 4 | 70 |
| O0010 | สลัดไก่ | 1 | 119 |
| O0011 | เค้กช็อกโกแลต | 1 | 99 |
| O0012 | เค้กช็อกโกแลต | 4 | 99 |
| O0013 | แซนด์วิช | 3 | 89 |
| O0014 | สลัดไก่ | 2 | 119 |
| O0015 | กาแฟเย็น | 2 | 65 |
| O0016 | แซนด์วิช | 2 | 89 |
| O0017 | โกโก้ | 4 | 70 |
| O0018 | ครัวซองต์ | 4 | 75 |
| O0019 | น้ำเปล่า | 3 | 20 |
| O0020 | โกโก้ | 2 | 70 |
| O0021 | เค้กช็อกโกแลต | 2 | 99 |
| O0022 | แซนด์วิช | 3 | 89 |
| O0023 | โกโก้ | 3 | 70 |
| O0024 | ชาไทย | 2 | 55 |
| O0025 | ชาไทย | 3 | 55 |
| O0026 | เค้กช็อกโกแลต | 3 | 99 |
| O0027 | สลัดไก่ | 1 | 119 |
| O0028 | ชาไทย | 3 | 55 |
| O0029 | กาแฟเย็น | 3 | 65 |
| O0030 | ชาไทย | 3 | 55 |
| O0031 | สลัดไก่ | 3 | 119 |
| O0032 | สลัดไก่ | 1 | 119 |
| O0033 | กาแฟเย็น | 2 | 65 |
| O0034 | เค้กช็อกโกแลต | 3 | 99 |
| O0035 | สลัดไก่ | 4 | 119 |
| O0036 | ครัวซองต์ | 1 | 75 |
| O0037 | สลัดไก่ | 2 | 119 |
| O0038 | น้ำเปล่า | 3 | 20 |
| O0039 | ครัวซองต์ | 1 | 75 |
| O0040 | เค้กช็อกโกแลต | 3 | 99 |
| O0041 | แซนด์วิช | 1 | 89 |
| O0042 | เค้กช็อกโกแลต | 3 | 99 |
| O0043 | น้ำเปล่า | 4 | 20 |
| O0044 | สลัดไก่ | 4 | 119 |
| O0045 | สลัดไก่ | 2 | 119 |
| O0046 | ครัวซองต์ | 1 | 75 |
| O0047 | กาแฟเย็น | 4 | 65 |
| O0048 | ครัวซองต์ | 1 | 75 |
| O0049 | โกโก้ | 1 | 70 |
| O0050 | โกโก้ | 3 | 70 |
| O0051 | กาแฟเย็น | 4 | 65 |
| O0052 | กาแฟเย็น | 3 | 65 |
| O0053 | กาแฟเย็น | 1 | 65 |
| O0054 | แซนด์วิช | 1 | 89 |
| O0055 | โกโก้ | 3 | 70 |
| O0056 | ชาไทย | 2 | 55 |
| O0057 | เค้กช็อกโกแลต | 1 | 99 |
| O0058 | แซนด์วิช | 3 | 89 |
| O0059 | น้ำเปล่า | 3 | 20 |
| O0060 | เค้กช็อกโกแลต | 4 | 99 |

_... แสดง 60 จาก 240 แถว (ดูครบใน CSV)_


## A5 — JOIN+SUM: ยอดขายสุทธิตามจังหวัด มาก→น้อย

```sql
SELECT c.province,
       COUNT(*)                  AS n_orders,
       ROUND(SUM(f.net_sales),2) AS net_sales
FROM fact_sales f
JOIN customers c ON f.customer_id = c.customer_id
GROUP BY c.province
ORDER BY net_sales DESC;
```

| province | n_orders | net_sales |
|---|---|---|
| ฉะเชิงเทรา | 99 | 17879.3 |
| ชลบุรี | 67 | 9518.6 |
| ระยอง | 43 | 7374.6 |
| กรุงเทพฯ | 16 | 2807.75 |


## A6 — Aggregation: ยอดขายสุทธิแต่ละ category

```sql
SELECT p.category,
       COUNT(*)                  AS n_orders,
       SUM(f.quantity)           AS units,
       ROUND(SUM(f.net_sales),2) AS net_sales
FROM fact_sales f
JOIN products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY net_sales DESC;
```

| category | n_orders | units | net_sales |
|---|---|---|---|
| เครื่องดื่ม | 129 | 319.0 | 16694.5 |
| เบเกอรี | 52 | 125.0 | 10829.1 |
| อาหาร | 44 | 98.0 | 10056.65 |


## A7 — TOP-N: ลูกค้า 5 รายยอดซื้อสะสมสูงสุด

```sql
SELECT c.customer_id, c.customer_name, c.province, c.segment,
       COUNT(*)                  AS n_orders,
       ROUND(SUM(f.net_sales),2) AS total_spent
FROM fact_sales f
JOIN customers c ON f.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name, c.province, c.segment
ORDER BY total_spent DESC
LIMIT 5;
```

| customer_id | customer_name | province | segment | n_orders | total_spent |
|---|---|---|---|---|---|
| C008 | ลูกค้า 008 | ชลบุรี | Walk-in | 9 | 1734.1 |
| C039 | ลูกค้า 039 | ฉะเชิงเทรา | Walk-in | 9 | 1557.7 |
| C031 | ลูกค้า 031 | ฉะเชิงเทรา | Walk-in | 8 | 1483.05 |
| C020 | ลูกค้า 020 | ฉะเชิงเทรา | Member | 7 | 1467.0 |
| C026 | ลูกค้า 026 | ชลบุรี | Walk-in | 12 | 1451.95 |


## A8 — HAVING: สินค้าที่ทำรายได้ > 2,000 บาท

```sql
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
```

| product_id | product_name | net_sales |
|---|---|---|
| P06 | เค้กช็อกโกแลต | 6895.35 |
| P07 | สลัดไก่ | 6229.65 |
| P05 | โกโก้ | 5684.0 |
| P02 | ชาไทย | 4922.5 |
| P01 | กาแฟเย็น | 4823.0 |
| P03 | ครัวซองต์ | 3933.75 |
| P04 | แซนด์วิช | 3827.0 |


## B1_dims — Star Schema: สร้าง dim_date / dim_customer / dim_product / dim_channel

```sql
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
```

| tbl | n_rows |
|---|---|
| dim_date | 92 |
| dim_customer | 40 |
| dim_product | 8 |
| dim_channel | 3 |


## B1_fact — Star Schema: fact_sales_star (FK = surrogate keys, measures = qty / gross / discount / net / cost / profit)

```sql
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
```

| source | n_rows | net_sales |
|---|---|---|
| fact_sales (view เดิม) | 225 | 37580.25 |
| fact_sales_star | 225 | 37580.25 |


## B1_view — VIEW ที่ JOIN Star Schema ครบ (ใช้ต่อในงาน OLAP)

```sql
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
```

| order_id | full_date | year | quarter | month | day_name | day_type | customer_id | customer_name | province | segment | product_id | product_name | category | channel | quantity | unit_price | discount_pct | gross_sales | discount_amount | net_sales | total_cost | gross_profit |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| O0001 | 2026-09-10 00:00:00 | 2026 | 3 | 2026-09 | Thu | Weekday | C019 | ลูกค้า 019 | ชลบุรี | Walk-in | P01 | กาแฟเย็น | เครื่องดื่ม | เดลิเวอรี | 3 | 65 | 0 | 195 | 0.0 | 195.0 | 96 | 99.0 |
| O0002 | 2026-08-26 00:00:00 | 2026 | 3 | 2026-08 | Wed | Weekday | C029 | ลูกค้า 029 | ชลบุรี | Walk-in | P05 | โกโก้ | เครื่องดื่ม | เดลิเวอรี | 2 | 70 | 5 | 140 | 7.0 | 133.0 | 68 | 65.0 |
| O0003 | 2026-07-09 00:00:00 | 2026 | 3 | 2026-07 | Thu | Weekday | C032 | ลูกค้า 032 | ฉะเชิงเทรา | Walk-in | P05 | โกโก้ | เครื่องดื่ม | หน้าร้าน | 3 | 70 | 5 | 210 | 10.5 | 199.5 | 102 | 97.5 |
| O0004 | 2026-07-19 00:00:00 | 2026 | 3 | 2026-07 | Sun | Weekend | C001 | ลูกค้า 001 | ชลบุรี | Walk-in | P08 | น้ำเปล่า | เครื่องดื่ม | หน้าร้าน | 1 | 20 | 10 | 20 | 2.0 | 18.0 | 7 | 11.0 |
| O0005 | 2026-07-11 00:00:00 | 2026 | 3 | 2026-07 | Sat | Weekend | C016 | ลูกค้า 016 | ระยอง | Member | P04 | แซนด์วิช | อาหาร | ออนไลน์ | 1 | 89 | 10 | 89 | 8.9 | 80.1 | 51 | 29.1 |
| O0006 | 2026-08-04 00:00:00 | 2026 | 3 | 2026-08 | Tue | Weekday | C010 | ลูกค้า 010 | ฉะเชิงเทรา | Walk-in | P06 | เค้กช็อกโกแลต | เบเกอรี | เดลิเวอรี | 1 | 99 | 10 | 99 | 9.9 | 89.1 | 59 | 30.1 |
| O0007 | 2026-09-01 00:00:00 | 2026 | 3 | 2026-09 | Tue | Weekday | C035 | ลูกค้า 035 | ชลบุรี | Member | P03 | ครัวซองต์ | เบเกอรี | เดลิเวอรี | 2 | 75 | 10 | 150 | 15.0 | 135.0 | 84 | 51.0 |
| O0008 | 2026-09-27 00:00:00 | 2026 | 3 | 2026-09 | Sun | Weekend | C006 | ลูกค้า 006 | ชลบุรี | Walk-in | P05 | โกโก้ | เครื่องดื่ม | ออนไลน์ | 4 | 70 | 0 | 280 | 0.0 | 280.0 | 136 | 144.0 |
| O0009 | 2026-09-14 00:00:00 | 2026 | 3 | 2026-09 | Mon | Weekday | C033 | ลูกค้า 033 | ฉะเชิงเทรา | Member | P05 | โกโก้ | เครื่องดื่ม | เดลิเวอรี | 4 | 70 | 10 | 280 | 28.0 | 252.0 | 136 | 116.0 |
| O0010 | 2026-07-26 00:00:00 | 2026 | 3 | 2026-07 | Sun | Weekend | C001 | ลูกค้า 001 | ชลบุรี | Walk-in | P07 | สลัดไก่ | อาหาร | เดลิเวอรี | 1 | 119 | 0 | 119 | 0.0 | 119.0 | 69 | 50.0 |


## B2 — Data Mart: VIEW mart_monthly_sales (เดือน × category × channel)

```sql
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
```

| month | category | channel | n_orders | units | revenue |
|---|---|---|---|---|---|
| 2026-07-01 00:00:00 | อาหาร | หน้าร้าน | 6 | 15.0 | 1407.4 |
| 2026-07-01 00:00:00 | อาหาร | ออนไลน์ | 4 | 12.0 | 1341.5 |
| 2026-07-01 00:00:00 | อาหาร | เดลิเวอรี | 8 | 17.0 | 1591.7 |
| 2026-07-01 00:00:00 | เครื่องดื่ม | หน้าร้าน | 15 | 27.0 | 1466.75 |
| 2026-07-01 00:00:00 | เครื่องดื่ม | ออนไลน์ | 11 | 25.0 | 1286.5 |
| 2026-07-01 00:00:00 | เครื่องดื่ม | เดลิเวอรี | 21 | 61.0 | 3136.25 |
| 2026-07-01 00:00:00 | เบเกอรี | หน้าร้าน | 2 | 7.0 | 693.0 |
| 2026-07-01 00:00:00 | เบเกอรี | ออนไลน์ | 9 | 20.0 | 1696.65 |
| 2026-07-01 00:00:00 | เบเกอรี | เดลิเวอรี | 5 | 12.0 | 1144.2 |
| 2026-08-01 00:00:00 | อาหาร | หน้าร้าน | 5 | 10.0 | 1178.1 |
| 2026-08-01 00:00:00 | อาหาร | ออนไลน์ | 3 | 6.0 | 546.2 |
| 2026-08-01 00:00:00 | อาหาร | เดลิเวอรี | 4 | 9.0 | 885.35 |
| 2026-08-01 00:00:00 | เครื่องดื่ม | หน้าร้าน | 10 | 24.0 | 1020.0 |
| 2026-08-01 00:00:00 | เครื่องดื่ม | ออนไลน์ | 14 | 36.0 | 1753.0 |
| 2026-08-01 00:00:00 | เครื่องดื่ม | เดลิเวอรี | 14 | 37.0 | 1960.75 |
| 2026-08-01 00:00:00 | เบเกอรี | หน้าร้าน | 7 | 16.0 | 1388.25 |
| 2026-08-01 00:00:00 | เบเกอรี | ออนไลน์ | 6 | 14.0 | 1138.5 |
| 2026-08-01 00:00:00 | เบเกอรี | เดลิเวอรี | 8 | 18.0 | 1609.5 |
| 2026-09-01 00:00:00 | อาหาร | หน้าร้าน | 5 | 9.0 | 1011.25 |
| 2026-09-01 00:00:00 | อาหาร | ออนไลน์ | 7 | 17.0 | 1738.15 |
| 2026-09-01 00:00:00 | อาหาร | เดลิเวอรี | 2 | 3.0 | 357.0 |
| 2026-09-01 00:00:00 | เครื่องดื่ม | หน้าร้าน | 21 | 48.0 | 2638.25 |
| 2026-09-01 00:00:00 | เครื่องดื่ม | ออนไลน์ | 8 | 25.0 | 1466.75 |
| 2026-09-01 00:00:00 | เครื่องดื่ม | เดลิเวอรี | 15 | 36.0 | 1966.25 |
| 2026-09-01 00:00:00 | เบเกอรี | หน้าร้าน | 7 | 19.0 | 1582.65 |
| 2026-09-01 00:00:00 | เบเกอรี | ออนไลน์ | 5 | 13.0 | 1075.05 |
| 2026-09-01 00:00:00 | เบเกอรี | เดลิเวอรี | 3 | 6.0 | 501.3 |


## B2_check — ตรวจ Data Mart: ยอดรวมใน mart ต้องเท่ากับ fact

```sql
SELECT (SELECT ROUND(SUM(revenue),2) FROM mart_monthly_sales) AS mart_total,
       (SELECT ROUND(SUM(net_sales),2) FROM fact_sales)       AS fact_total,
       (SELECT SUM(n_orders) FROM mart_monthly_sales)         AS mart_orders,
       (SELECT COUNT(*) FROM fact_sales)                      AS fact_orders;
```

| mart_total | fact_total | mart_orders | fact_orders |
|---|---|---|---|
| 37580.25 | 37580.25 | 225.0 | 225.0 |


## B3_quality — Data Quality: 3 ประเด็นหลัก + ข้อเพิ่มเติม (นับจำนวนที่ผิด)

```sql
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
```

| check_name | n_bad |
|---|---|
| customer_id หาย (NULL/ว่าง) | 0 |
| customer_id ไม่พบใน customers | 0 |
| quantity ไม่สมเหตุสมผล (NULL, <=0, >20) | 0 |
| product_id ไม่พบใน products | 0 |
| order_id ซ้ำ | 0 |
| discount_pct นอกช่วง 0-100 | 0 |
| unit_price ไม่ตรง list_price | 0 |
| status นอกเหนือ Completed/Cancelled | 0 |
| order_date นอกช่วง ก.ค.-ก.ย. 2026 | 0 |


## B3_detail — Data Quality: แสดงแถวที่มีปัญหา (ถ้าว่าง = ข้อมูลสะอาด)

```sql
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
```

_(ไม่มีแถวผลลัพธ์)_


## B3_test — ทดลองฉีดข้อมูลเสีย 3 แถว (ใน temp table) เพื่อพิสูจน์ว่า SQL ตรวจจับได้จริง

```sql
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
```

| order_id | customer_id | product_id | quantity | issue_and_action |
|---|---|---|---|---|
| X0001 |  | P01 | 2 | missing customer_id → ส่งไป reject / ใส่ Unknown member (customer_key=-1) |
| X0002 | C001 | P01 | -3 | quantity <= 0 → reject / ตรวจว่าเป็นการคืนสินค้าหรือไม่ |
| X0003 | C001 | P99 | 1 | unknown product_id → reject, แจ้งเจ้าของ product master |


## C1 — ยอดขายรายวัน + Moving Average 7 แถว (ROWS)

```sql
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
```

| order_date | n_orders | daily_sales | ma7_rows |
|---|---|---|---|
| 2026-07-01 00:00:00 | 2 | 245.75 | 245.75 |
| 2026-07-02 00:00:00 | 2 | 197.5 | 221.63 |
| 2026-07-03 00:00:00 | 1 | 49.5 | 164.25 |
| 2026-07-04 00:00:00 | 3 | 316.25 | 202.25 |
| 2026-07-05 00:00:00 | 2 | 140.0 | 189.8 |
| 2026-07-06 00:00:00 | 1 | 220.0 | 194.83 |
| 2026-07-07 00:00:00 | 2 | 648.4 | 259.63 |
| 2026-07-08 00:00:00 | 2 | 476.0 | 292.52 |
| 2026-07-09 00:00:00 | 4 | 300.5 | 307.24 |
| 2026-07-10 00:00:00 | 5 | 983.3 | 440.64 |
| 2026-07-11 00:00:00 | 3 | 279.1 | 435.33 |
| 2026-07-12 00:00:00 | 3 | 324.0 | 461.61 |
| 2026-07-13 00:00:00 | 2 | 472.0 | 497.61 |
| 2026-07-15 00:00:00 | 3 | 186.75 | 431.66 |
| 2026-07-16 00:00:00 | 3 | 478.5 | 432.02 |
| 2026-07-17 00:00:00 | 5 | 1274.7 | 571.19 |
| 2026-07-18 00:00:00 | 2 | 255.25 | 467.19 |
| 2026-07-19 00:00:00 | 4 | 769.0 | 537.17 |
| 2026-07-20 00:00:00 | 5 | 890.0 | 618.03 |
| 2026-07-21 00:00:00 | 1 | 199.5 | 579.1 |
| 2026-07-22 00:00:00 | 5 | 547.5 | 630.64 |
| 2026-07-23 00:00:00 | 1 | 75.0 | 572.99 |
| 2026-07-24 00:00:00 | 2 | 405.3 | 448.79 |
| 2026-07-25 00:00:00 | 2 | 333.0 | 459.9 |
| 2026-07-26 00:00:00 | 6 | 1296.65 | 535.28 |
| 2026-07-27 00:00:00 | 1 | 60.0 | 416.71 |
| 2026-07-28 00:00:00 | 5 | 1081.5 | 542.71 |
| 2026-07-29 00:00:00 | 4 | 1259.0 | 644.35 |
| 2026-08-01 00:00:00 | 2 | 344.0 | 682.78 |
| 2026-08-02 00:00:00 | 2 | 317.0 | 670.16 |
| 2026-08-03 00:00:00 | 4 | 741.5 | 728.52 |
| 2026-08-04 00:00:00 | 2 | 129.1 | 561.73 |
| 2026-08-05 00:00:00 | 2 | 123.5 | 570.8 |
| 2026-08-06 00:00:00 | 3 | 368.0 | 468.87 |
| 2026-08-07 00:00:00 | 1 | 282.15 | 329.32 |
| 2026-08-08 00:00:00 | 3 | 580.0 | 363.04 |
| 2026-08-09 00:00:00 | 2 | 324.0 | 364.04 |
| 2026-08-10 00:00:00 | 1 | 63.0 | 267.11 |
| 2026-08-11 00:00:00 | 4 | 690.0 | 347.24 |
| 2026-08-12 00:00:00 | 3 | 339.25 | 378.06 |
| 2026-08-13 00:00:00 | 6 | 1171.0 | 492.77 |
| 2026-08-14 00:00:00 | 1 | 99.0 | 466.61 |
| 2026-08-15 00:00:00 | 5 | 1182.15 | 552.63 |
| 2026-08-16 00:00:00 | 2 | 398.2 | 563.23 |
| 2026-08-18 00:00:00 | 2 | 451.5 | 618.73 |
| 2026-08-19 00:00:00 | 2 | 505.0 | 592.3 |
| 2026-08-20 00:00:00 | 1 | 38.0 | 549.26 |
| 2026-08-21 00:00:00 | 4 | 629.25 | 471.87 |
| 2026-08-22 00:00:00 | 1 | 148.5 | 478.94 |
| 2026-08-23 00:00:00 | 2 | 249.0 | 345.64 |
| 2026-08-24 00:00:00 | 3 | 521.1 | 363.19 |
| 2026-08-25 00:00:00 | 2 | 79.0 | 309.98 |
| 2026-08-26 00:00:00 | 2 | 358.0 | 288.98 |
| 2026-08-27 00:00:00 | 1 | 396.0 | 340.12 |
| 2026-08-28 00:00:00 | 4 | 408.25 | 308.55 |
| 2026-08-29 00:00:00 | 2 | 218.7 | 318.58 |
| 2026-08-30 00:00:00 | 1 | 126.0 | 301.01 |
| 2026-08-31 00:00:00 | 1 | 199.5 | 255.06 |
| 2026-09-01 00:00:00 | 2 | 373.0 | 297.06 |
| 2026-09-02 00:00:00 | 3 | 321.75 | 291.89 |

_... แสดง 60 จาก 84 แถว (ดูครบใน CSV)_


## C1_calendar — MA 7 วันจริง: เติมวันที่ไม่มีขายเป็น 0 ด้วย date spine แล้วเทียบกับแบบ 7 แถว

```sql
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
```

| order_date | daily_sales | no_sales_day | ma7_true_days |
|---|---|---|---|
| 2026-07-01 00:00:00 | 245.75 | False | 245.75 |
| 2026-07-02 00:00:00 | 197.5 | False | 221.63 |
| 2026-07-03 00:00:00 | 49.5 | False | 164.25 |
| 2026-07-04 00:00:00 | 316.25 | False | 202.25 |
| 2026-07-05 00:00:00 | 140.0 | False | 189.8 |
| 2026-07-06 00:00:00 | 220.0 | False | 194.83 |
| 2026-07-07 00:00:00 | 648.4 | False | 259.63 |
| 2026-07-08 00:00:00 | 476.0 | False | 292.52 |
| 2026-07-09 00:00:00 | 300.5 | False | 307.24 |
| 2026-07-10 00:00:00 | 983.3 | False | 440.64 |
| 2026-07-11 00:00:00 | 279.1 | False | 435.33 |
| 2026-07-12 00:00:00 | 324.0 | False | 461.61 |
| 2026-07-13 00:00:00 | 472.0 | False | 497.61 |
| 2026-07-14 00:00:00 | 0.0 | True | 404.99 |
| 2026-07-15 00:00:00 | 186.75 | False | 363.66 |
| 2026-07-16 00:00:00 | 478.5 | False | 389.09 |
| 2026-07-17 00:00:00 | 1274.7 | False | 430.72 |
| 2026-07-18 00:00:00 | 255.25 | False | 427.31 |
| 2026-07-19 00:00:00 | 769.0 | False | 490.89 |
| 2026-07-20 00:00:00 | 890.0 | False | 550.6 |
| 2026-07-21 00:00:00 | 199.5 | False | 579.1 |
| 2026-07-22 00:00:00 | 547.5 | False | 630.64 |
| 2026-07-23 00:00:00 | 75.0 | False | 572.99 |
| 2026-07-24 00:00:00 | 405.3 | False | 448.79 |
| 2026-07-25 00:00:00 | 333.0 | False | 459.9 |
| 2026-07-26 00:00:00 | 1296.65 | False | 535.28 |
| 2026-07-27 00:00:00 | 60.0 | False | 416.71 |
| 2026-07-28 00:00:00 | 1081.5 | False | 542.71 |
| 2026-07-29 00:00:00 | 1259.0 | False | 644.35 |
| 2026-07-30 00:00:00 | 0.0 | True | 633.64 |
| 2026-07-31 00:00:00 | 0.0 | True | 575.74 |
| 2026-08-01 00:00:00 | 344.0 | False | 577.31 |
| 2026-08-02 00:00:00 | 317.0 | False | 437.36 |
| 2026-08-03 00:00:00 | 741.5 | False | 534.71 |
| 2026-08-04 00:00:00 | 129.1 | False | 398.66 |
| 2026-08-05 00:00:00 | 123.5 | False | 236.44 |
| 2026-08-06 00:00:00 | 368.0 | False | 289.01 |
| 2026-08-07 00:00:00 | 282.15 | False | 329.32 |
| 2026-08-08 00:00:00 | 580.0 | False | 363.04 |
| 2026-08-09 00:00:00 | 324.0 | False | 364.04 |
| 2026-08-10 00:00:00 | 63.0 | False | 267.11 |
| 2026-08-11 00:00:00 | 690.0 | False | 347.24 |
| 2026-08-12 00:00:00 | 339.25 | False | 378.06 |
| 2026-08-13 00:00:00 | 1171.0 | False | 492.77 |
| 2026-08-14 00:00:00 | 99.0 | False | 466.61 |
| 2026-08-15 00:00:00 | 1182.15 | False | 552.63 |
| 2026-08-16 00:00:00 | 398.2 | False | 563.23 |
| 2026-08-17 00:00:00 | 0.0 | True | 554.23 |
| 2026-08-18 00:00:00 | 451.5 | False | 520.16 |
| 2026-08-19 00:00:00 | 505.0 | False | 543.84 |
| 2026-08-20 00:00:00 | 38.0 | False | 381.98 |
| 2026-08-21 00:00:00 | 629.25 | False | 457.73 |
| 2026-08-22 00:00:00 | 148.5 | False | 310.06 |
| 2026-08-23 00:00:00 | 249.0 | False | 288.75 |
| 2026-08-24 00:00:00 | 521.1 | False | 363.19 |
| 2026-08-25 00:00:00 | 79.0 | False | 309.98 |
| 2026-08-26 00:00:00 | 358.0 | False | 288.98 |
| 2026-08-27 00:00:00 | 396.0 | False | 340.12 |
| 2026-08-28 00:00:00 | 408.25 | False | 308.55 |
| 2026-08-29 00:00:00 | 218.7 | False | 318.58 |

_... แสดง 60 จาก 92 แถว (ดูครบใน CSV)_


## C1_gaps — นับวันที่ไม่มียอดขาย (เหตุผลที่ 7 แถว ≠ 7 วัน)

```sql
SELECT COUNT(*) AS days_in_period,
       COUNT(d.order_date) AS days_with_sales,
       COUNT(*) - COUNT(d.order_date) AS days_without_sales
FROM generate_series(DATE '2026-07-01', DATE '2026-09-30', INTERVAL 1 DAY) t(x)
LEFT JOIN (SELECT DISTINCT order_date FROM fact_sales) d ON d.order_date = CAST(t.x AS DATE);
```

| days_in_period | days_with_sales | days_without_sales |
|---|---|---|
| 92 | 84 | 8 |


## C2 — Customer Features (RFM): last_order, frequency, monetary + recency/score

```sql
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
```

| customer_id | last_order | frequency | monetary | avg_order_value | recency_days | r_score | f_score | m_score | province | segment | rfm_total | rfm_segment |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C008 | 2026-09-27 00:00:00 | 9 | 1734.1 | 192.68 | 4 | 2 | 3 | 3 | ชลบุรี | Walk-in | 8 | Champion |
| C039 | 2026-09-20 00:00:00 | 9 | 1557.7 | 173.08 | 11 | 2 | 3 | 3 | ฉะเชิงเทรา | Walk-in | 8 | Champion |
| C031 | 2026-09-30 00:00:00 | 8 | 1483.05 | 185.38 | 1 | 3 | 3 | 3 | ฉะเชิงเทรา | Walk-in | 9 | Champion |
| C020 | 2026-09-30 00:00:00 | 7 | 1467.0 | 209.57 | 1 | 3 | 3 | 3 | ฉะเชิงเทรา | Member | 9 | Champion |
| C026 | 2026-09-27 00:00:00 | 12 | 1451.95 | 121.0 | 4 | 3 | 3 | 3 | ชลบุรี | Walk-in | 9 | Champion |
| C013 | 2026-09-10 00:00:00 | 9 | 1419.3 | 157.7 | 21 | 2 | 3 | 3 | ระยอง | Member | 8 | Champion |
| C015 | 2026-09-30 00:00:00 | 5 | 1343.0 | 268.6 | 1 | 3 | 2 | 3 | ฉะเชิงเทรา | Member | 8 | Champion |
| C017 | 2026-09-26 00:00:00 | 7 | 1315.0 | 187.86 | 5 | 2 | 3 | 3 | ระยอง | Walk-in | 8 | Champion |
| C034 | 2026-09-21 00:00:00 | 7 | 1304.0 | 186.29 | 10 | 2 | 3 | 3 | ระยอง | Walk-in | 8 | Champion |
| C032 | 2026-09-08 00:00:00 | 8 | 1288.1 | 161.01 | 23 | 1 | 3 | 3 | ฉะเชิงเทรา | Walk-in | 7 | Loyal |
| C003 | 2026-09-28 00:00:00 | 5 | 1225.6 | 245.12 | 3 | 3 | 2 | 3 | ฉะเชิงเทรา | Walk-in | 8 | Champion |
| C023 | 2026-08-21 00:00:00 | 6 | 1211.9 | 201.98 | 41 | 1 | 3 | 3 | ฉะเชิงเทรา | Walk-in | 7 | Loyal |
| C011 | 2026-09-25 00:00:00 | 5 | 1194.15 | 238.83 | 6 | 2 | 2 | 3 | ระยอง | Walk-in | 7 | Loyal |
| C040 | 2026-09-29 00:00:00 | 6 | 1105.4 | 184.23 | 2 | 3 | 2 | 2 | ฉะเชิงเทรา | Walk-in | 7 | Loyal |
| C012 | 2026-08-28 00:00:00 | 6 | 1073.15 | 178.86 | 34 | 1 | 2 | 2 | ฉะเชิงเทรา | Member | 5 | At risk |
| C018 | 2026-09-22 00:00:00 | 4 | 1027.0 | 256.75 | 9 | 2 | 1 | 2 | ฉะเชิงเทรา | Walk-in | 5 | Regular |
| C028 | 2026-08-26 00:00:00 | 6 | 1008.0 | 168.0 | 36 | 1 | 2 | 2 | ฉะเชิงเทรา | Member | 5 | At risk |
| C006 | 2026-09-27 00:00:00 | 6 | 993.8 | 165.63 | 4 | 3 | 2 | 2 | ชลบุรี | Walk-in | 7 | Loyal |
| C036 | 2026-09-30 00:00:00 | 8 | 958.55 | 119.82 | 1 | 3 | 3 | 2 | กรุงเทพฯ | Walk-in | 8 | Champion |
| C009 | 2026-09-09 00:00:00 | 7 | 928.3 | 132.61 | 22 | 1 | 3 | 2 | ระยอง | Member | 6 | Loyal |
| C038 | 2026-09-30 00:00:00 | 5 | 928.2 | 185.64 | 1 | 3 | 1 | 2 | กรุงเทพฯ | Walk-in | 6 | Loyal |
| C025 | 2026-08-15 00:00:00 | 3 | 921.0 | 307.0 | 47 | 1 | 1 | 2 | กรุงเทพฯ | Member | 4 | At risk |
| C035 | 2026-09-21 00:00:00 | 8 | 905.5 | 113.19 | 10 | 2 | 3 | 2 | ชลบุรี | Member | 7 | Loyal |
| C001 | 2026-09-08 00:00:00 | 6 | 899.0 | 149.83 | 23 | 1 | 2 | 2 | ชลบุรี | Walk-in | 5 | At risk |
| C030 | 2026-09-08 00:00:00 | 5 | 882.0 | 176.4 | 23 | 1 | 2 | 2 | ฉะเชิงเทรา | Walk-in | 5 | At risk |
| C033 | 2026-09-21 00:00:00 | 5 | 861.75 | 172.35 | 10 | 2 | 2 | 2 | ฉะเชิงเทรา | Member | 6 | Loyal |
| C014 | 2026-09-30 00:00:00 | 5 | 805.75 | 161.15 | 1 | 3 | 2 | 1 | ระยอง | Walk-in | 6 | Loyal |
| C029 | 2026-09-21 00:00:00 | 6 | 766.5 | 127.75 | 10 | 2 | 2 | 1 | ชลบุรี | Walk-in | 5 | Regular |
| C007 | 2026-09-21 00:00:00 | 6 | 742.0 | 123.67 | 10 | 2 | 2 | 1 | ชลบุรี | Walk-in | 5 | Regular |
| C027 | 2026-09-08 00:00:00 | 4 | 737.0 | 184.25 | 23 | 1 | 1 | 1 | ฉะเชิงเทรา | Member | 3 | At risk |
| C019 | 2026-09-13 00:00:00 | 4 | 733.5 | 183.38 | 18 | 2 | 1 | 1 | ชลบุรี | Walk-in | 4 | Regular |
| C005 | 2026-08-30 00:00:00 | 4 | 477.75 | 119.44 | 32 | 1 | 1 | 1 | ชลบุรี | Member | 3 | At risk |
| C002 | 2026-08-14 00:00:00 | 2 | 456.0 | 228.0 | 48 | 1 | 1 | 1 | ชลบุรี | Member | 3 | At risk |
| C022 | 2026-09-29 00:00:00 | 3 | 455.0 | 151.67 | 2 | 3 | 1 | 1 | ฉะเชิงเทรา | Walk-in | 5 | Regular |
| C037 | 2026-09-11 00:00:00 | 4 | 451.5 | 112.88 | 20 | 2 | 1 | 1 | ฉะเชิงเทรา | Walk-in | 4 | Regular |
| C021 | 2026-09-30 00:00:00 | 4 | 414.05 | 103.51 | 1 | 3 | 1 | 1 | ฉะเชิงเทรา | Walk-in | 5 | Regular |
| C016 | 2026-08-21 00:00:00 | 3 | 408.1 | 136.03 | 41 | 1 | 1 | 1 | ระยอง | Member | 3 | At risk |
| C024 | 2026-09-06 00:00:00 | 4 | 358.5 | 89.63 | 25 | 1 | 1 | 1 | ชลบุรี | Member | 3 | At risk |
| C010 | 2026-09-29 00:00:00 | 2 | 229.1 | 114.55 | 2 | 3 | 1 | 1 | ฉะเชิงเทรา | Walk-in | 5 | Regular |
| C004 | 2026-08-25 00:00:00 | 2 | 59.0 | 29.5 | 37 | 1 | 1 | 1 | ฉะเชิงเทรา | Member | 3 | At risk |


## C2_segment_summary — สรุปกลุ่ม RFM (ใช้ตอบว่า "ลูกค้ากลุ่มใดควรได้แคมเปญ")

```sql
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
```

| rfm_segment | n_customers | avg_freq | avg_monetary | total_monetary |
|---|---|---|---|---|
| Champion | 11 | 7.82 | 1387.2 | 15259.25 |
| Loyal | 10 | 6.1 | 1022.29 | 10222.85 |
| At risk | 11 | 4.09 | 661.77 | 7279.5 |
| Regular | 8 | 4.13 | 602.33 | 4818.65 |


## C3_feature_table — ตารางฟีเจอร์รายวันสำหรับพยากรณ์ยอดขาย (กัน data leakage: ใช้เฉพาะข้อมูลอดีต)

```sql
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
```

| order_date | target_sales_today | dow | is_weekend | lag_1 | lag_7 | ma7_past_only | split |
|---|---|---|---|---|---|---|---|
| 2026-07-01 00:00:00 | 245.75 | 3 | 0 |  |  |  | train |
| 2026-07-02 00:00:00 | 197.5 | 4 | 0 | 245.75 |  | 245.75 | train |
| 2026-07-03 00:00:00 | 49.5 | 5 | 0 | 197.5 |  | 221.63 | train |
| 2026-07-04 00:00:00 | 316.25 | 6 | 1 | 49.5 |  | 164.25 | train |
| 2026-07-05 00:00:00 | 140.0 | 0 | 1 | 316.25 |  | 202.25 | train |
| 2026-07-06 00:00:00 | 220.0 | 1 | 0 | 140.0 |  | 189.8 | train |
| 2026-07-07 00:00:00 | 648.4 | 2 | 0 | 220.0 |  | 194.83 | train |
| 2026-07-08 00:00:00 | 476.0 | 3 | 0 | 648.4 | 245.75 | 259.63 | train |
| 2026-07-09 00:00:00 | 300.5 | 4 | 0 | 476.0 | 197.5 | 292.52 | train |
| 2026-07-10 00:00:00 | 983.3 | 5 | 0 | 300.5 | 49.5 | 307.24 | train |
| 2026-07-11 00:00:00 | 279.1 | 6 | 1 | 983.3 | 316.25 | 440.64 | train |
| 2026-07-12 00:00:00 | 324.0 | 0 | 1 | 279.1 | 140.0 | 435.33 | train |
| 2026-07-13 00:00:00 | 472.0 | 1 | 0 | 324.0 | 220.0 | 461.61 | train |
| 2026-07-14 00:00:00 | 0.0 | 2 | 0 | 472.0 | 648.4 | 497.61 | train |
| 2026-07-15 00:00:00 | 186.75 | 3 | 0 | 0.0 | 476.0 | 404.99 | train |
| 2026-07-16 00:00:00 | 478.5 | 4 | 0 | 186.75 | 300.5 | 363.66 | train |
| 2026-07-17 00:00:00 | 1274.7 | 5 | 0 | 478.5 | 983.3 | 389.09 | train |
| 2026-07-18 00:00:00 | 255.25 | 6 | 1 | 1274.7 | 279.1 | 430.72 | train |
| 2026-07-19 00:00:00 | 769.0 | 0 | 1 | 255.25 | 324.0 | 427.31 | train |
| 2026-07-20 00:00:00 | 890.0 | 1 | 0 | 769.0 | 472.0 | 490.89 | train |
| 2026-07-21 00:00:00 | 199.5 | 2 | 0 | 890.0 | 0.0 | 550.6 | train |
| 2026-07-22 00:00:00 | 547.5 | 3 | 0 | 199.5 | 186.75 | 579.1 | train |
| 2026-07-23 00:00:00 | 75.0 | 4 | 0 | 547.5 | 478.5 | 630.64 | train |
| 2026-07-24 00:00:00 | 405.3 | 5 | 0 | 75.0 | 1274.7 | 572.99 | train |
| 2026-07-25 00:00:00 | 333.0 | 6 | 1 | 405.3 | 255.25 | 448.79 | train |
| 2026-07-26 00:00:00 | 1296.65 | 0 | 1 | 333.0 | 769.0 | 459.9 | train |
| 2026-07-27 00:00:00 | 60.0 | 1 | 0 | 1296.65 | 890.0 | 535.28 | train |
| 2026-07-28 00:00:00 | 1081.5 | 2 | 0 | 60.0 | 199.5 | 416.71 | train |
| 2026-07-29 00:00:00 | 1259.0 | 3 | 0 | 1081.5 | 547.5 | 542.71 | train |
| 2026-07-30 00:00:00 | 0.0 | 4 | 0 | 1259.0 | 75.0 | 644.35 | train |
| 2026-07-31 00:00:00 | 0.0 | 5 | 0 | 0.0 | 405.3 | 633.64 | train |
| 2026-08-01 00:00:00 | 344.0 | 6 | 1 | 0.0 | 333.0 | 575.74 | train |
| 2026-08-02 00:00:00 | 317.0 | 0 | 1 | 344.0 | 1296.65 | 577.31 | train |
| 2026-08-03 00:00:00 | 741.5 | 1 | 0 | 317.0 | 60.0 | 437.36 | train |
| 2026-08-04 00:00:00 | 129.1 | 2 | 0 | 741.5 | 1081.5 | 534.71 | train |
| 2026-08-05 00:00:00 | 123.5 | 3 | 0 | 129.1 | 1259.0 | 398.66 | train |
| 2026-08-06 00:00:00 | 368.0 | 4 | 0 | 123.5 | 0.0 | 236.44 | train |
| 2026-08-07 00:00:00 | 282.15 | 5 | 0 | 368.0 | 0.0 | 289.01 | train |
| 2026-08-08 00:00:00 | 580.0 | 6 | 1 | 282.15 | 344.0 | 329.32 | train |
| 2026-08-09 00:00:00 | 324.0 | 0 | 1 | 580.0 | 317.0 | 363.04 | train |
| 2026-08-10 00:00:00 | 63.0 | 1 | 0 | 324.0 | 741.5 | 364.04 | train |
| 2026-08-11 00:00:00 | 690.0 | 2 | 0 | 63.0 | 129.1 | 267.11 | train |
| 2026-08-12 00:00:00 | 339.25 | 3 | 0 | 690.0 | 123.5 | 347.24 | train |
| 2026-08-13 00:00:00 | 1171.0 | 4 | 0 | 339.25 | 368.0 | 378.06 | train |
| 2026-08-14 00:00:00 | 99.0 | 5 | 0 | 1171.0 | 282.15 | 492.77 | train |
| 2026-08-15 00:00:00 | 1182.15 | 6 | 1 | 99.0 | 580.0 | 466.61 | train |
| 2026-08-16 00:00:00 | 398.2 | 0 | 1 | 1182.15 | 324.0 | 552.63 | train |
| 2026-08-17 00:00:00 | 0.0 | 1 | 0 | 398.2 | 63.0 | 563.23 | train |
| 2026-08-18 00:00:00 | 451.5 | 2 | 0 | 0.0 | 690.0 | 554.23 | train |
| 2026-08-19 00:00:00 | 505.0 | 3 | 0 | 451.5 | 339.25 | 520.16 | train |
| 2026-08-20 00:00:00 | 38.0 | 4 | 0 | 505.0 | 1171.0 | 543.84 | train |
| 2026-08-21 00:00:00 | 629.25 | 5 | 0 | 38.0 | 99.0 | 381.98 | train |
| 2026-08-22 00:00:00 | 148.5 | 6 | 1 | 629.25 | 1182.15 | 457.73 | train |
| 2026-08-23 00:00:00 | 249.0 | 0 | 1 | 148.5 | 398.2 | 310.06 | train |
| 2026-08-24 00:00:00 | 521.1 | 1 | 0 | 249.0 | 0.0 | 288.75 | train |
| 2026-08-25 00:00:00 | 79.0 | 2 | 0 | 521.1 | 451.5 | 363.19 | train |
| 2026-08-26 00:00:00 | 358.0 | 3 | 0 | 79.0 | 505.0 | 309.98 | train |
| 2026-08-27 00:00:00 | 396.0 | 4 | 0 | 358.0 | 38.0 | 288.98 | train |
| 2026-08-28 00:00:00 | 408.25 | 5 | 0 | 396.0 | 629.25 | 340.12 | train |
| 2026-08-29 00:00:00 | 218.7 | 6 | 1 | 408.25 | 148.5 | 308.55 | train |

_... แสดง 60 จาก 92 แถว (ดูครบใน CSV)_


## D1_channel — ช่องทางใดทำรายได้ดีที่สุด (+ AOV, % share, อัตรายกเลิก)

```sql
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
```

| channel | completed_orders | cancelled_orders | cancel_rate_pct | net_sales | aov | share_pct |
|---|---|---|---|---|---|---|
| เดลิเวอรี | 80 | 7 | 8.0 | 13152.3 | 164.4 | 35.0 |
| หน้าร้าน | 78 | 1 | 1.3 | 12385.65 | 158.79 | 33.0 |
| ออนไลน์ | 67 | 7 | 9.5 | 12042.3 | 179.74 | 32.0 |


## D2_product_profit — สินค้าใดควรผลักดัน: ยอดขาย + กำไรขั้นต้น + margin

```sql
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
```

| product_id | product_name | category | units | net_sales | cost | gross_profit | margin_pct | profit_rank |
|---|---|---|---|---|---|---|---|---|
| P05 | โกโก้ | เครื่องดื่ม | 85.0 | 5684.0 | 2890.0 | 2794.0 | 49.2 | 1 |
| P06 | เค้กช็อกโกแลต | เบเกอรี | 71.0 | 6895.35 | 4189.0 | 2706.35 | 39.2 | 2 |
| P02 | ชาไทย | เครื่องดื่ม | 93.0 | 4922.5 | 2325.0 | 2597.5 | 52.8 | 3 |
| P07 | สลัดไก่ | อาหาร | 54.0 | 6229.65 | 3726.0 | 2503.65 | 40.2 | 4 |
| P01 | กาแฟเย็น | เครื่องดื่ม | 76.0 | 4823.0 | 2432.0 | 2391.0 | 49.6 | 5 |
| P03 | ครัวซองต์ | เบเกอรี | 54.0 | 3933.75 | 2268.0 | 1665.75 | 42.3 | 6 |
| P04 | แซนด์วิช | อาหาร | 44.0 | 3827.0 | 2244.0 | 1583.0 | 41.4 | 7 |
| P08 | น้ำเปล่า | เครื่องดื่ม | 65.0 | 1265.0 | 455.0 | 810.0 | 64.0 | 8 |


## D3_segment — Member vs Walk-in

```sql
SELECT c.segment,
       COUNT(DISTINCT c.customer_id)  AS n_customers,
       COUNT(*)                       AS n_orders,
       ROUND(SUM(f.net_sales),2)      AS net_sales,
       ROUND(SUM(f.net_sales)/COUNT(*),2) AS aov,
       ROUND(1.0*COUNT(*)/COUNT(DISTINCT c.customer_id),2) AS orders_per_customer
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY c.segment ORDER BY net_sales DESC;
```

| segment | n_customers | n_orders | net_sales | aov | orders_per_customer |
|---|---|---|---|---|---|
| Walk-in | 25 | 150 | 25156.9 | 167.71 | 6.0 |
| Member | 15 | 75 | 12423.35 | 165.64 | 5.0 |


## D4_kpi — KPI ภาพรวม

```sql
SELECT COUNT(*)                                AS completed_orders,
       COUNT(DISTINCT customer_id)             AS active_customers,
       SUM(quantity)                           AS units,
       ROUND(SUM(quantity*unit_price),2)       AS gross_sales,
       ROUND(SUM(quantity*unit_price) - SUM(net_sales),2) AS total_discount,
       ROUND(SUM(net_sales),2)                 AS net_sales,
       ROUND(SUM(net_sales)/COUNT(DISTINCT order_id),2) AS aov,
       ROUND(AVG(net_sales),2)                 AS avg_line
FROM fact_sales;
```

| completed_orders | active_customers | units | gross_sales | total_discount | net_sales | aov | avg_line |
|---|---|---|---|---|---|---|---|
| 225.0 | 40.0 | 542.0 | 38726.0 | 1145.75 | 37580.25 | 167.02 | 167.02 |


## D5_month_growth — ยอดรายเดือน + % เปลี่ยนแปลงเดือนต่อเดือน (LAG)

```sql
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
```

| month | n_orders | net_sales | prev_month | mom_pct |
|---|---|---|---|---|
| 2026-07 | 81 | 13763.95 |  |  |
| 2026-08 | 71 | 11479.65 | 13763.95 | -16.6 |
| 2026-09 | 73 | 12336.65 | 11479.65 | 7.5 |


## O1_rollup — Roll-up: ยอดรายเดือน

```sql
SELECT strftime(order_date,'%Y-%m') AS month, ROUND(SUM(net_sales),2) AS revenue
FROM fact_sales GROUP BY month ORDER BY month;
```

| month | revenue |
|---|---|
| 2026-07 | 13763.95 |
| 2026-08 | 11479.65 |
| 2026-09 | 12336.65 |


## O2_drilldown — Drill-down: เดือน × จังหวัด

```sql
SELECT strftime(f.order_date,'%Y-%m') AS month, c.province, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY month, c.province ORDER BY month, c.province;
```

| month | province | revenue |
|---|---|---|
| 2026-07 | กรุงเทพฯ | 1064.2 |
| 2026-07 | ฉะเชิงเทรา | 6966.35 |
| 2026-07 | ชลบุรี | 3009.3 |
| 2026-07 | ระยอง | 2724.1 |
| 2026-08 | กรุงเทพฯ | 1182.25 |
| 2026-08 | ฉะเชิงเทรา | 4980.95 |
| 2026-08 | ชลบุรี | 2753.0 |
| 2026-08 | ระยอง | 2563.45 |
| 2026-09 | กรุงเทพฯ | 561.3 |
| 2026-09 | ฉะเชิงเทรา | 5932.0 |
| 2026-09 | ชลบุรี | 3756.3 |
| 2026-09 | ระยอง | 2087.05 |


## O3_drilldown_day — Drill-down ในมิติเวลา: รายวันเฉพาะกันยายน

```sql
SELECT order_date, ROUND(SUM(net_sales),2) AS revenue
FROM fact_sales WHERE strftime(order_date,'%Y-%m') = '2026-09'
GROUP BY order_date ORDER BY order_date;
```

| order_date | revenue |
|---|---|
| 2026-09-01 00:00:00 | 373.0 |
| 2026-09-02 00:00:00 | 321.75 |
| 2026-09-04 00:00:00 | 1073.3 |
| 2026-09-05 00:00:00 | 605.0 |
| 2026-09-06 00:00:00 | 600.0 |
| 2026-09-07 00:00:00 | 130.0 |
| 2026-09-08 00:00:00 | 411.1 |
| 2026-09-09 00:00:00 | 544.05 |
| 2026-09-10 00:00:00 | 843.0 |
| 2026-09-11 00:00:00 | 210.0 |
| 2026-09-12 00:00:00 | 476.0 |
| 2026-09-13 00:00:00 | 448.0 |
| 2026-09-14 00:00:00 | 252.0 |
| 2026-09-15 00:00:00 | 193.05 |
| 2026-09-16 00:00:00 | 18.0 |
| 2026-09-17 00:00:00 | 346.0 |
| 2026-09-19 00:00:00 | 274.25 |
| 2026-09-20 00:00:00 | 497.05 |
| 2026-09-21 00:00:00 | 561.25 |
| 2026-09-22 00:00:00 | 110.0 |
| 2026-09-25 00:00:00 | 189.0 |
| 2026-09-26 00:00:00 | 939.5 |
| 2026-09-27 00:00:00 | 673.0 |
| 2026-09-28 00:00:00 | 214.2 |
| 2026-09-29 00:00:00 | 922.4 |
| 2026-09-30 00:00:00 | 1111.75 |


## O4_slice — Slice: เฉพาะกันยายน แยกจังหวัด

```sql
SELECT c.province, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
WHERE strftime(f.order_date,'%Y-%m') = '2026-09'
GROUP BY c.province ORDER BY revenue DESC;
```

| province | revenue |
|---|---|
| ฉะเชิงเทรา | 5932.0 |
| ชลบุรี | 3756.3 |
| ระยอง | 2087.05 |
| กรุงเทพฯ | 561.3 |


## O5_dice — Dice: กันยายน + เครื่องดื่ม + ชลบุรี/ระยอง

```sql
SELECT c.province, f.channel, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f
JOIN customers c USING (customer_id)
JOIN products  p USING (product_id)
WHERE strftime(f.order_date,'%Y-%m') = '2026-09'
  AND p.category = 'เครื่องดื่ม'
  AND c.province IN ('ชลบุรี','ระยอง')
GROUP BY c.province, f.channel ORDER BY c.province, revenue DESC;
```

| province | channel | revenue |
|---|---|---|
| ชลบุรี | ออนไลน์ | 861.25 |
| ชลบุรี | หน้าร้าน | 783.0 |
| ชลบุรี | เดลิเวอรี | 681.0 |
| ระยอง | หน้าร้าน | 711.75 |
| ระยอง | เดลิเวอรี | 581.25 |


## O6_having — WHERE vs HAVING: จังหวัดที่ยอดกันยายน > 3,000

```sql
SELECT c.province, ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
WHERE strftime(f.order_date,'%Y-%m') = '2026-09'     -- กรองแถว (ก่อนรวม)
GROUP BY c.province
HAVING SUM(f.net_sales) > 3000                        -- กรองกลุ่ม (หลังรวม)
ORDER BY revenue DESC;
```

| province | revenue |
|---|---|
| ฉะเชิงเทรา | 5932.0 |
| ชลบุรี | 3756.3 |


## O7_drillthrough — Drill-through: รายการต้นทางของ ชลบุรี กันยายน

```sql
SELECT f.order_id, f.order_date, c.customer_id, p.product_name, f.quantity, f.unit_price, f.discount_pct, f.net_sales
FROM fact_sales f JOIN customers c USING (customer_id) JOIN products p USING (product_id)
WHERE c.province = 'ชลบุรี' AND strftime(f.order_date,'%Y-%m') = '2026-09'
ORDER BY f.order_date, f.order_id;
```

| order_id | order_date | customer_id | product_name | quantity | unit_price | discount_pct | net_sales |
|---|---|---|---|---|---|---|---|
| O0007 | 2026-09-01 00:00:00 | C035 | ครัวซองต์ | 2 | 75 | 10 | 135.0 |
| O0224 | 2026-09-04 00:00:00 | C008 | สลัดไก่ | 3 | 119 | 0 | 357.0 |
| O0170 | 2026-09-05 00:00:00 | C019 | กาแฟเย็น | 2 | 65 | 0 | 130.0 |
| O0020 | 2026-09-06 00:00:00 | C007 | โกโก้ | 2 | 70 | 0 | 140.0 |
| O0114 | 2026-09-06 00:00:00 | C024 | โกโก้ | 1 | 70 | 0 | 70.0 |
| O0236 | 2026-09-07 00:00:00 | C007 | กาแฟเย็น | 2 | 65 | 0 | 130.0 |
| O0235 | 2026-09-08 00:00:00 | C001 | น้ำเปล่า | 3 | 20 | 5 | 57.0 |
| O0182 | 2026-09-09 00:00:00 | C008 | โกโก้ | 4 | 70 | 5 | 266.0 |
| O0001 | 2026-09-10 00:00:00 | C019 | กาแฟเย็น | 3 | 65 | 0 | 195.0 |
| O0033 | 2026-09-10 00:00:00 | C008 | กาแฟเย็น | 2 | 65 | 0 | 130.0 |
| O0121 | 2026-09-10 00:00:00 | C029 | ชาไทย | 2 | 55 | 10 | 99.0 |
| O0057 | 2026-09-13 00:00:00 | C006 | เค้กช็อกโกแลต | 1 | 99 | 0 | 99.0 |
| O0225 | 2026-09-13 00:00:00 | C019 | ชาไทย | 4 | 55 | 5 | 209.0 |
| O0130 | 2026-09-16 00:00:00 | C008 | น้ำเปล่า | 1 | 20 | 10 | 18.0 |
| O0138 | 2026-09-17 00:00:00 | C035 | โกโก้ | 4 | 70 | 5 | 266.0 |
| O0029 | 2026-09-19 00:00:00 | C026 | กาแฟเย็น | 3 | 65 | 5 | 185.25 |
| O0064 | 2026-09-20 00:00:00 | C026 | สลัดไก่ | 1 | 119 | 5 | 113.05 |
| O0193 | 2026-09-20 00:00:00 | C026 | เค้กช็อกโกแลต | 1 | 99 | 0 | 99.0 |
| O0015 | 2026-09-21 00:00:00 | C029 | กาแฟเย็น | 2 | 65 | 0 | 130.0 |
| O0086 | 2026-09-21 00:00:00 | C035 | น้ำเปล่า | 1 | 20 | 0 | 20.0 |
| O0239 | 2026-09-21 00:00:00 | C007 | ครัวซองต์ | 4 | 75 | 0 | 300.0 |
| O0008 | 2026-09-27 00:00:00 | C006 | โกโก้ | 4 | 70 | 0 | 280.0 |
| O0094 | 2026-09-27 00:00:00 | C008 | ครัวซองต์ | 2 | 75 | 0 | 150.0 |
| O0106 | 2026-09-27 00:00:00 | C026 | แซนด์วิช | 2 | 89 | 0 | 178.0 |


## O8_pivot_case — Pivot ด้วย SUM(CASE): จังหวัด × เดือน

```sql
SELECT c.province,
       ROUND(SUM(CASE WHEN strftime(f.order_date,'%Y-%m')='2026-07' THEN f.net_sales ELSE 0 END),2) AS jul,
       ROUND(SUM(CASE WHEN strftime(f.order_date,'%Y-%m')='2026-08' THEN f.net_sales ELSE 0 END),2) AS aug,
       ROUND(SUM(CASE WHEN strftime(f.order_date,'%Y-%m')='2026-09' THEN f.net_sales ELSE 0 END),2) AS sep,
       ROUND(SUM(f.net_sales),2) AS total
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY c.province ORDER BY total DESC;
```

| province | jul | aug | sep | total |
|---|---|---|---|---|
| ฉะเชิงเทรา | 6966.35 | 4980.95 | 5932.0 | 17879.3 |
| ชลบุรี | 3009.3 | 2753.0 | 3756.3 | 9518.6 |
| ระยอง | 2724.1 | 2563.45 | 2087.05 | 7374.6 |
| กรุงเทพฯ | 1064.2 | 1182.25 | 561.3 | 2807.75 |


## O9_pivot_duckdb — Pivot ด้วยคำสั่ง PIVOT ของ DuckDB: category × channel

```sql
SELECT * FROM (
    PIVOT (SELECT p.category, f.channel, f.net_sales
           FROM fact_sales f JOIN products p USING (product_id))
    ON channel USING ROUND(SUM(net_sales),2)
    GROUP BY category
) ORDER BY category;
```

| category | หน้าร้าน | ออนไลน์ | เดลิเวอรี |
|---|---|---|---|
| อาหาร | 3596.75 | 3625.85 | 2834.05 |
| เครื่องดื่ม | 5125.0 | 4506.25 | 7063.25 |
| เบเกอรี | 3663.9 | 3910.2 | 3255.0 |


## O10_union_total — Subtotal + Grand total ด้วย UNION ALL

```sql
SELECT * FROM (
    SELECT strftime(order_date,'%Y-%m') AS month, ROUND(SUM(net_sales),2) AS revenue
    FROM fact_sales GROUP BY 1
    UNION ALL
    SELECT 'ALL', ROUND(SUM(net_sales),2) FROM fact_sales
) ORDER BY CASE WHEN month='ALL' THEN 1 ELSE 0 END, month;
```

| month | revenue |
|---|---|
| 2026-07 | 13763.95 |
| 2026-08 | 11479.65 |
| 2026-09 | 12336.65 |
| ALL | 37580.25 |


## O11_rollup_op — GROUP BY ROLLUP: subtotal ตามลำดับชั้น category → product (+ grand total)

```sql
SELECT COALESCE(p.category, '== GRAND TOTAL ==') AS category,
       COALESCE(p.product_name, CASE WHEN p.category IS NOT NULL THEN '-- subtotal --' END) AS product_name,
       ROUND(SUM(f.net_sales),2) AS revenue,
       GROUPING(p.category, p.product_name) AS grouping_level
FROM fact_sales f JOIN products p USING (product_id)
GROUP BY ROLLUP (p.category, p.product_name)
ORDER BY p.category NULLS LAST, grouping_level, revenue DESC;
```

| category | product_name | revenue | grouping_level |
|---|---|---|---|
| อาหาร | สลัดไก่ | 6229.65 | 0 |
| อาหาร | แซนด์วิช | 3827.0 | 0 |
| อาหาร | -- subtotal -- | 10056.65 | 1 |
| เครื่องดื่ม | โกโก้ | 5684.0 | 0 |
| เครื่องดื่ม | ชาไทย | 4922.5 | 0 |
| เครื่องดื่ม | กาแฟเย็น | 4823.0 | 0 |
| เครื่องดื่ม | น้ำเปล่า | 1265.0 | 0 |
| เครื่องดื่ม | -- subtotal -- | 16694.5 | 1 |
| เบเกอรี | เค้กช็อกโกแลต | 6895.35 | 0 |
| เบเกอรี | ครัวซองต์ | 3933.75 | 0 |
| เบเกอรี | -- subtotal -- | 10829.1 | 1 |
| == GRAND TOTAL == |  | 37580.25 | 3 |


## O12_cube — GROUP BY CUBE: ทุกการรวมของ province × channel

```sql
SELECT COALESCE(c.province,'(ทุกจังหวัด)') AS province,
       COALESCE(f.channel,'(ทุกช่องทาง)')  AS channel,
       ROUND(SUM(f.net_sales),2) AS revenue
FROM fact_sales f JOIN customers c USING (customer_id)
GROUP BY CUBE (c.province, f.channel)
ORDER BY c.province NULLS LAST, f.channel NULLS LAST;
```

| province | channel | revenue |
|---|---|---|
| กรุงเทพฯ | หน้าร้าน | 957.0 |
| กรุงเทพฯ | ออนไลน์ | 702.5 |
| กรุงเทพฯ | เดลิเวอรี | 1148.25 |
| กรุงเทพฯ | (ทุกช่องทาง) | 2807.75 |
| ฉะเชิงเทรา | หน้าร้าน | 6478.0 |
| ฉะเชิงเทรา | ออนไลน์ | 5617.75 |
| ฉะเชิงเทรา | เดลิเวอรี | 5783.55 |
| ฉะเชิงเทรา | (ทุกช่องทาง) | 17879.3 |
| ชลบุรี | หน้าร้าน | 1896.75 |
| ชลบุรี | ออนไลน์ | 4255.95 |
| ชลบุรี | เดลิเวอรี | 3365.9 |
| ชลบุรี | (ทุกช่องทาง) | 9518.6 |
| ระยอง | หน้าร้าน | 3053.9 |
| ระยอง | ออนไลน์ | 1466.1 |
| ระยอง | เดลิเวอรี | 2854.6 |
| ระยอง | (ทุกช่องทาง) | 7374.6 |
| (ทุกจังหวัด) | หน้าร้าน | 12385.65 |
| (ทุกจังหวัด) | ออนไลน์ | 12042.3 |
| (ทุกจังหวัด) | เดลิเวอรี | 13152.3 |
| (ทุกจังหวัด) | (ทุกช่องทาง) | 37580.25 |


## O13_rank_in_group — Window: อันดับสินค้าในแต่ละ category (QUALIFY)

```sql
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
```

| category | product_name | revenue | rank_in_category | pct_of_category |
|---|---|---|---|---|
| อาหาร | สลัดไก่ | 6229.65 | 1 | 61.9 |
| อาหาร | แซนด์วิช | 3827.0 | 2 | 38.1 |
| เครื่องดื่ม | โกโก้ | 5684.0 | 1 | 34.0 |
| เครื่องดื่ม | ชาไทย | 4922.5 | 2 | 29.5 |
| เครื่องดื่ม | กาแฟเย็น | 4823.0 | 3 | 28.9 |
| เครื่องดื่ม | น้ำเปล่า | 1265.0 | 4 | 7.6 |
| เบเกอรี | เค้กช็อกโกแลต | 6895.35 | 1 | 63.7 |
| เบเกอรี | ครัวซองต์ | 3933.75 | 2 | 36.3 |


## O14_top_per_group — Top-1 category ของแต่ละจังหวัด (Aggregate ก่อน แล้ว ROW_NUMBER)

```sql
WITH pc AS (
    SELECT c.province, p.category, SUM(f.net_sales) AS revenue
    FROM fact_sales f JOIN customers c USING (customer_id) JOIN products p USING (product_id)
    GROUP BY c.province, p.category
)
SELECT province, category, ROUND(revenue,2) AS revenue
FROM pc
QUALIFY ROW_NUMBER() OVER (PARTITION BY province ORDER BY revenue DESC) = 1
ORDER BY revenue DESC;
```

| province | category | revenue |
|---|---|---|
| ฉะเชิงเทรา | เครื่องดื่ม | 7815.5 |
| ชลบุรี | เครื่องดื่ม | 4649.5 |
| ระยอง | เครื่องดื่ม | 3301.0 |
| กรุงเทพฯ | เบเกอรี | 1403.25 |


## O15_aov — AOV vs AVG(line) และการนับออเดอร์ (Grain)

```sql
SELECT ROUND(SUM(net_sales),2)                       AS revenue,
       COUNT(*)                                      AS line_count,
       COUNT(DISTINCT order_id)                      AS order_count,
       SUM(quantity)                                 AS units,
       ROUND(SUM(net_sales)/COUNT(DISTINCT order_id),2) AS aov,
       ROUND(AVG(net_sales),2)                       AS avg_line
FROM fact_sales;
```

| revenue | line_count | order_count | units | aov | avg_line |
|---|---|---|---|---|---|
| 37580.25 | 225.0 | 225.0 | 542.0 | 167.02 | 167.02 |


## O16_cumulative — ยอดสะสม (running total) รายวัน

```sql
WITH d AS (SELECT order_date, SUM(net_sales) AS s FROM fact_sales GROUP BY 1)
SELECT order_date, ROUND(s,2) AS daily_sales,
       ROUND(SUM(s) OVER (ORDER BY order_date),2) AS running_total,
       ROUND(SUM(s) OVER (PARTITION BY strftime(order_date,'%Y-%m') ORDER BY order_date),2) AS month_to_date
FROM d ORDER BY order_date;
```

| order_date | daily_sales | running_total | month_to_date |
|---|---|---|---|
| 2026-07-01 00:00:00 | 245.75 | 245.75 | 245.75 |
| 2026-07-02 00:00:00 | 197.5 | 443.25 | 443.25 |
| 2026-07-03 00:00:00 | 49.5 | 492.75 | 492.75 |
| 2026-07-04 00:00:00 | 316.25 | 809.0 | 809.0 |
| 2026-07-05 00:00:00 | 140.0 | 949.0 | 949.0 |
| 2026-07-06 00:00:00 | 220.0 | 1169.0 | 1169.0 |
| 2026-07-07 00:00:00 | 648.4 | 1817.4 | 1817.4 |
| 2026-07-08 00:00:00 | 476.0 | 2293.4 | 2293.4 |
| 2026-07-09 00:00:00 | 300.5 | 2593.9 | 2593.9 |
| 2026-07-10 00:00:00 | 983.3 | 3577.2 | 3577.2 |
| 2026-07-11 00:00:00 | 279.1 | 3856.3 | 3856.3 |
| 2026-07-12 00:00:00 | 324.0 | 4180.3 | 4180.3 |
| 2026-07-13 00:00:00 | 472.0 | 4652.3 | 4652.3 |
| 2026-07-15 00:00:00 | 186.75 | 4839.05 | 4839.05 |
| 2026-07-16 00:00:00 | 478.5 | 5317.55 | 5317.55 |
| 2026-07-17 00:00:00 | 1274.7 | 6592.25 | 6592.25 |
| 2026-07-18 00:00:00 | 255.25 | 6847.5 | 6847.5 |
| 2026-07-19 00:00:00 | 769.0 | 7616.5 | 7616.5 |
| 2026-07-20 00:00:00 | 890.0 | 8506.5 | 8506.5 |
| 2026-07-21 00:00:00 | 199.5 | 8706.0 | 8706.0 |
| 2026-07-22 00:00:00 | 547.5 | 9253.5 | 9253.5 |
| 2026-07-23 00:00:00 | 75.0 | 9328.5 | 9328.5 |
| 2026-07-24 00:00:00 | 405.3 | 9733.8 | 9733.8 |
| 2026-07-25 00:00:00 | 333.0 | 10066.8 | 10066.8 |
| 2026-07-26 00:00:00 | 1296.65 | 11363.45 | 11363.45 |
| 2026-07-27 00:00:00 | 60.0 | 11423.45 | 11423.45 |
| 2026-07-28 00:00:00 | 1081.5 | 12504.95 | 12504.95 |
| 2026-07-29 00:00:00 | 1259.0 | 13763.95 | 13763.95 |
| 2026-08-01 00:00:00 | 344.0 | 14107.95 | 344.0 |
| 2026-08-02 00:00:00 | 317.0 | 14424.95 | 661.0 |
| 2026-08-03 00:00:00 | 741.5 | 15166.45 | 1402.5 |
| 2026-08-04 00:00:00 | 129.1 | 15295.55 | 1531.6 |
| 2026-08-05 00:00:00 | 123.5 | 15419.05 | 1655.1 |
| 2026-08-06 00:00:00 | 368.0 | 15787.05 | 2023.1 |
| 2026-08-07 00:00:00 | 282.15 | 16069.2 | 2305.25 |
| 2026-08-08 00:00:00 | 580.0 | 16649.2 | 2885.25 |
| 2026-08-09 00:00:00 | 324.0 | 16973.2 | 3209.25 |
| 2026-08-10 00:00:00 | 63.0 | 17036.2 | 3272.25 |
| 2026-08-11 00:00:00 | 690.0 | 17726.2 | 3962.25 |
| 2026-08-12 00:00:00 | 339.25 | 18065.45 | 4301.5 |
| 2026-08-13 00:00:00 | 1171.0 | 19236.45 | 5472.5 |
| 2026-08-14 00:00:00 | 99.0 | 19335.45 | 5571.5 |
| 2026-08-15 00:00:00 | 1182.15 | 20517.6 | 6753.65 |
| 2026-08-16 00:00:00 | 398.2 | 20915.8 | 7151.85 |
| 2026-08-18 00:00:00 | 451.5 | 21367.3 | 7603.35 |
| 2026-08-19 00:00:00 | 505.0 | 21872.3 | 8108.35 |
| 2026-08-20 00:00:00 | 38.0 | 21910.3 | 8146.35 |
| 2026-08-21 00:00:00 | 629.25 | 22539.55 | 8775.6 |
| 2026-08-22 00:00:00 | 148.5 | 22688.05 | 8924.1 |
| 2026-08-23 00:00:00 | 249.0 | 22937.05 | 9173.1 |
| 2026-08-24 00:00:00 | 521.1 | 23458.15 | 9694.2 |
| 2026-08-25 00:00:00 | 79.0 | 23537.15 | 9773.2 |
| 2026-08-26 00:00:00 | 358.0 | 23895.15 | 10131.2 |
| 2026-08-27 00:00:00 | 396.0 | 24291.15 | 10527.2 |
| 2026-08-28 00:00:00 | 408.25 | 24699.4 | 10935.45 |
| 2026-08-29 00:00:00 | 218.7 | 24918.1 | 11154.15 |
| 2026-08-30 00:00:00 | 126.0 | 25044.1 | 11280.15 |
| 2026-08-31 00:00:00 | 199.5 | 25243.6 | 11479.65 |
| 2026-09-01 00:00:00 | 373.0 | 25616.6 | 373.0 |
| 2026-09-02 00:00:00 | 321.75 | 25938.35 | 694.75 |

_... แสดง 60 จาก 84 แถว (ดูครบใน CSV)_


## O17_weekday — ยอดตามวันในสัปดาห์ (ใช้ dim_date)

```sql
SELECT d.day_of_week, d.day_name, d.day_type, COUNT(f.order_id) AS n_orders, ROUND(COALESCE(SUM(f.net_sales),0),2) AS revenue
FROM dim_date d LEFT JOIN fact_sales_star f ON f.date_key = d.date_key
GROUP BY d.day_of_week, d.day_name, d.day_type
ORDER BY d.day_of_week;

-- =====================================================================
-- SUMMARY / AGGREGATE TABLE (แนวแลปสัปดาห์ 10) บน Coast Café
-- =====================================================================
```

| day_of_week | day_name | day_type | n_orders | revenue |
|---|---|---|---|---|
| 0 | Sun | Weekend | 38 | 6161.9 |
| 1 | Mon | Weekday | 26 | 4324.55 |
| 2 | Tue | Weekday | 31 | 5288.55 |
| 3 | Wed | Weekday | 39 | 6036.3 |
| 4 | Thu | Weekday | 29 | 4213.5 |
| 5 | Fri | Weekday | 29 | 5603.75 |
| 6 | Sat | Weekend | 33 | 5951.7 |


## T1_baseline — Baseline: เดือน × สินค้า จาก fact

```sql
SELECT strftime(order_date,'%Y-%m') AS sales_month, product_id,
       ROUND(SUM(net_sales),2) AS revenue, SUM(quantity) AS quantity, COUNT(*) AS order_count
FROM fact_sales
GROUP BY sales_month, product_id
ORDER BY sales_month, product_id;
```

| sales_month | product_id | revenue | quantity | order_count |
|---|---|---|---|---|
| 2026-07 | P01 | 2265.25 | 36.0 | 14 |
| 2026-07 | P02 | 1861.75 | 35.0 | 14 |
| 2026-07 | P03 | 697.5 | 10.0 | 7 |
| 2026-07 | P04 | 2091.5 | 24.0 | 11 |
| 2026-07 | P05 | 1333.5 | 20.0 | 8 |
| 2026-07 | P06 | 2836.35 | 29.0 | 9 |
| 2026-07 | P07 | 2249.1 | 20.0 | 7 |
| 2026-07 | P08 | 429.0 | 22.0 | 11 |
| 2026-08 | P01 | 838.5 | 13.0 | 6 |
| 2026-08 | P02 | 1509.75 | 29.0 | 10 |
| 2026-08 | P03 | 1785.0 | 24.0 | 11 |
| 2026-08 | P04 | 854.4 | 10.0 | 4 |
| 2026-08 | P05 | 1858.5 | 28.0 | 11 |
| 2026-08 | P06 | 2351.25 | 24.0 | 10 |
| 2026-08 | P07 | 1755.25 | 15.0 | 8 |
| 2026-08 | P08 | 527.0 | 27.0 | 11 |
| 2026-09 | P01 | 1719.25 | 27.0 | 12 |
| 2026-09 | P02 | 1551.0 | 29.0 | 11 |
| 2026-09 | P03 | 1451.25 | 20.0 | 7 |
| 2026-09 | P04 | 881.1 | 10.0 | 5 |
| 2026-09 | P05 | 2492.0 | 37.0 | 13 |
| 2026-09 | P06 | 1707.75 | 18.0 | 8 |
| 2026-09 | P07 | 2225.3 | 19.0 | 9 |
| 2026-09 | P08 | 309.0 | 16.0 | 8 |


## T2_create_summary — สร้าง Summary Table (Grain = 1 เดือน × 1 สินค้า, PK = (sales_month, product_id))

```sql
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
```

| sales_month | product_id | revenue | quantity | order_count |
|---|---|---|---|---|
| 2026-07 | P01 | 2265.25 | 36 | 14 |
| 2026-07 | P02 | 1861.75 | 35 | 14 |
| 2026-07 | P03 | 697.5 | 10 | 7 |
| 2026-07 | P04 | 2091.5 | 24 | 11 |
| 2026-07 | P05 | 1333.5 | 20 | 8 |
| 2026-07 | P06 | 2836.35 | 29 | 9 |
| 2026-07 | P07 | 2249.1 | 20 | 7 |
| 2026-07 | P08 | 429.0 | 22 | 11 |
| 2026-08 | P01 | 838.5 | 13 | 6 |
| 2026-08 | P02 | 1509.75 | 29 | 10 |
| 2026-08 | P03 | 1785.0 | 24 | 11 |
| 2026-08 | P04 | 854.4 | 10 | 4 |
| 2026-08 | P05 | 1858.5 | 28 | 11 |
| 2026-08 | P06 | 2351.25 | 24 | 10 |
| 2026-08 | P07 | 1755.25 | 15 | 8 |
| 2026-08 | P08 | 527.0 | 27 | 11 |
| 2026-09 | P01 | 1719.25 | 27 | 12 |
| 2026-09 | P02 | 1551.0 | 29 | 11 |
| 2026-09 | P03 | 1451.25 | 20 | 7 |
| 2026-09 | P04 | 881.1 | 10 | 5 |
| 2026-09 | P05 | 2492.0 | 37 | 13 |
| 2026-09 | P06 | 1707.75 | 18 | 8 |
| 2026-09 | P07 | 2225.3 | 19 | 9 |
| 2026-09 | P08 | 309.0 | 16 | 8 |


## T3_validate — Validation: fact vs summary

```sql
SELECT 'revenue' AS metric, (SELECT ROUND(SUM(net_sales),2) FROM fact_sales) AS from_fact,
       (SELECT SUM(revenue) FROM summary_month_product) AS from_summary
UNION ALL SELECT 'quantity', (SELECT SUM(quantity) FROM fact_sales), (SELECT SUM(quantity) FROM summary_month_product)
UNION ALL SELECT 'order_count', (SELECT COUNT(*) FROM fact_sales), (SELECT SUM(order_count) FROM summary_month_product);
```

| metric | from_fact | from_summary |
|---|---|---|
| revenue | 37580.25 | 37580.25 |
| quantity | 542.0 | 542.0 |
| order_count | 225.0 | 225.0 |


## T4_explain — EXPLAIN: fact vs summary (ดูจำนวนแถวที่ scan)

```sql
EXPLAIN SELECT strftime(order_date,'%Y-%m'), product_id, SUM(net_sales) FROM fact_sales GROUP BY 1,2;
```

| explain_key | explain_value |
|---|---|
| physical_plan | ╭─ Projection ─────────────────────────────╮
│ Projections:                             │
│ #0, __internal_decompress_string(#1), #2 │
│ ~8 rows                                  │
╰─────────────────────┬────────────────────╯
╭─ Hash Group By ─────┴────────────────────╮
│ Groups: #0, #1                           │
│ Aggregates: sum(#2)                      │
│ ~8 rows                                  │
╰─────────────────────┬────────────────────╯
╭─ Projection ────────┴────────────────────╮
│ Projections:                             │
│ strftime(order_date, '%Y-%m'),           │
│ product_id, net_sales                    │
│ ~120 rows                                │
╰─────────────────────┬────────────────────╯
╭─ Projection ────────┴────────────────────╮
│ Projections:                             │
│ #0,                                      │
│ __internal_compress_string_uinteger(#1), │
│ #2                                       │
│ ~120 rows                                │
╰─────────────────────┬────────────────────╯
╭─ Projection ────────┴────────────────────╮
│ Projections: order_date, product_id,     │
│              net_sales                   │
│ ~120 rows                                │
╰─────────────────────┬────────────────────╯
╭─ Seq Scan ──────────┴────────────────────╮
│ Table: coast_cafe.main.orders            │
│ Type: Sequential Scan                    │
│ Projections: order_date, product_id,     │
│              quantity, unit_price,       │
│              discount_pct                │
│ Filters: status = 'Completed'            │
│ ~120 rows                                │
╰──────────────────────────────────────────╯
 |


## T5_stale — Data Stale: เพิ่มออเดอร์ใหม่ใน orders แล้ว summary ไม่เปลี่ยน (เพราะเป็นตารางที่คำนวณไว้ล่วงหน้า)

```sql
INSERT INTO orders VALUES ('O9999', DATE '2026-09-30', 'C001', 'P01', 10, 65, 0, 'หน้าร้าน', 'Completed');
SELECT 'fact (สด)' AS source, ROUND(SUM(net_sales),2) AS revenue_sep_p01 FROM fact_sales
 WHERE strftime(order_date,'%Y-%m')='2026-09' AND product_id='P01'
UNION ALL
SELECT 'summary (เก่า)', revenue FROM summary_month_product WHERE sales_month='2026-09' AND product_id='P01';
```

| source | revenue_sep_p01 |
|---|---|
| fact (สด) | 2369.25 |
| summary (เก่า) | 1719.25 |


## T6_refresh — Refresh แบบ incremental: ลบเฉพาะเดือนที่กระทบ แล้วคำนวณใหม่ + ตรวจซ้ำ

```sql
DELETE FROM summary_month_product WHERE sales_month = '2026-09';
INSERT INTO summary_month_product
SELECT strftime(order_date,'%Y-%m'), product_id, ROUND(SUM(net_sales),2), SUM(quantity), COUNT(*), now()
FROM fact_sales WHERE strftime(order_date,'%Y-%m') = '2026-09' GROUP BY 1, 2;
SELECT 'revenue' AS metric, (SELECT ROUND(SUM(net_sales),2) FROM fact_sales) AS from_fact,
       (SELECT SUM(revenue) FROM summary_month_product) AS from_summary,
       (SELECT ROUND(SUM(net_sales),2) FROM fact_sales) = (SELECT SUM(revenue) FROM summary_month_product) AS is_match;
```

| metric | from_fact | from_summary | is_match |
|---|---|---|---|
| revenue | 38230.25 | 38230.25 | True |


## T7_cleanup — ลบออเดอร์ทดลอง O9999 คืนข้อมูลเดิม แล้ว refresh เต็ม (full refresh)

```sql
DELETE FROM orders WHERE order_id = 'O9999';
DELETE FROM summary_month_product;
INSERT INTO summary_month_product
SELECT strftime(order_date,'%Y-%m'), product_id, ROUND(SUM(net_sales),2), SUM(quantity), COUNT(*), now()
FROM fact_sales GROUP BY 1, 2;
SELECT COUNT(*) AS orders_rows, (SELECT SUM(revenue) FROM summary_month_product) AS summary_total FROM orders;

-- =====================================================================
-- OLTP vs OLAP (สไลด์ 5): guarded UPDATE ในธุรกรรม
-- =====================================================================
```

| orders_rows | summary_total |
|---|---|
| 240.0 | 37580.25 |


## X1_oltp — OLTP: เปลี่ยนสถานะออเดอร์เดียวแบบมีเงื่อนไข (รันซ้ำจะไม่กระทบแถวไหน)

```sql
CREATE OR REPLACE TEMP TABLE oltp_orders AS SELECT 'O1004' AS order_id, 'PENDING' AS status;
BEGIN TRANSACTION;
UPDATE oltp_orders SET status = 'PAID' WHERE order_id = 'O1004' AND status = 'PENDING';
COMMIT;
SELECT * FROM oltp_orders;
```

| order_id | status |
|---|---|
| O1004 | PAID |


## X2_export_note — ส่งออกผลเป็น CSV (CLI) — ตัวอย่าง

```sql
-- COPY (SELECT * FROM mart_monthly_sales ORDER BY month) TO 'mart_monthly_sales.csv' (HEADER, DELIMITER ',');
SELECT 'ใช้ COPY (...) TO ''file.csv'' (HEADER) เพื่อส่งออกผล' AS note;
```

| note |
|---|
| ใช้ COPY (...) TO 'file.csv' (HEADER) เพื่อส่งออกผล |


## pivot_province_month (pandas)

| province | 2026-07 | 2026-08 | 2026-09 | Total |
|---|---|---|---|---|
| กรุงเทพฯ | 1064.2 | 1182.25 | 561.3 | 2807.75 |
| ฉะเชิงเทรา | 6966.35 | 4980.95 | 5932.0 | 17879.3 |
| ชลบุรี | 3009.3 | 2753.0 | 3756.3 | 9518.6 |
| ระยอง | 2724.1 | 2563.45 | 2087.05 | 7374.6 |
| Total | 13763.95 | 11479.65 | 12336.65 | 37580.25 |


## pivot_september_category_province (pandas)

| category | กรุงเทพฯ | ฉะเชิงเทรา | ชลบุรี | ระยอง |
|---|---|---|---|---|
| อาหาร | 0.0 | 1988.3 | 648.05 | 470.05 |
| เครื่องดื่ม | 294.0 | 2159.0 | 2325.25 | 1293.0 |
| เบเกอรี | 267.3 | 1784.7 | 783.0 | 324.0 |


## pivot_WRONG_mean (pandas)

| province | 2026-07 | 2026-08 | 2026-09 |
|---|---|---|---|
| กรุงเทพฯ | 212.84 | 197.04 | 112.26 |
| ฉะเชิงเทรา | 193.51 | 150.94 | 197.73 |
| ชลบุรี | 125.39 | 144.89 | 156.51 |
| ระยอง | 170.26 | 197.19 | 149.08 |


## pivot_drink_only (pandas)

| province | 2026-07 | 2026-08 | 2026-09 | Total |
|---|---|---|---|---|
| กรุงเทพฯ | 224.5 | 410.0 | 294.0 | 928.5 |
| ฉะเชิงเทรา | 3340.25 | 2316.25 | 2159.0 | 7815.5 |
| ชลบุรี | 975.75 | 1348.5 | 2325.25 | 4649.5 |
| ระยอง | 1349.0 | 659.0 | 1293.0 | 3301.0 |
| Total | 5889.5 | 4733.75 | 6071.25 | 16694.5 |


**assert ผ่าน:** Grand total = 37580.25 บาท
