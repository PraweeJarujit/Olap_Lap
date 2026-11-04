# ผลแลปสัปดาห์ 9 (warehouse.db)

## q01.sql
```sql
-- 2.2 ตรวจ Grain: COUNT(*)=จำนวนรายการ, COUNT(DISTINCT order_id)=จำนวนออเดอร์, SUM(quantity)=ชิ้น, SUM(amount)=บาท
SELECT COUNT(*) AS line_count,
       COUNT(DISTINCT order_id) AS order_count,
       SUM(quantity) AS units,
       SUM(amount) AS revenue
FROM sales;

```
```
 line_count  order_count  units  revenue
          8            6     23     1390
```

## q02.sql
```sql
-- Roll-up: วัน -> เดือน
SELECT month, SUM(amount) AS revenue
FROM sales
GROUP BY month
ORDER BY month;

```
```
  month  revenue
2026-08      490
2026-09      900
```

## q03.sql
```sql
-- Drill-down: เพิ่มมิติสถานที่ (province) ในผลรายเดือน
SELECT month, province, SUM(amount) AS revenue
FROM sales
GROUP BY month, province
ORDER BY month, province;

```
```
  month province  revenue
2026-08  Bangkok      310
2026-08 Chonburi      180
2026-09  Bangkok      540
2026-09 Chonburi      360
```

## q04.sql
```sql
-- Drill-down ในมิติเวลา: เดือน -> วัน (เฉพาะกันยายน)
SELECT full_date, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY full_date
ORDER BY full_date;

```
```
 full_date  revenue
2026-09-09      360
2026-09-10      300
2026-09-11      240
```

## q05.sql
```sql
-- Slice: ตัดมิติเวลาเหลือกันยายน แล้วสรุปตามจังหวัด
SELECT province, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY province
ORDER BY province;

```
```
province  revenue
 Bangkok      540
Chonburi      360
```

## q06.sql
```sql
-- Dice: หลายเงื่อนไขหลายมิติ (กันยายน + Drink + Bangkok/Chonburi)
SELECT province, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
  AND category = 'Drink'
  AND province IN ('Bangkok', 'Chonburi')
GROUP BY province
ORDER BY province;

```
```
province  revenue
 Bangkok      300
Chonburi      200
```

## q07.sql
```sql
-- WHERE กรองแถว (เดือน) ก่อนรวม / HAVING กรองกลุ่ม (ยอดรวม) หลังรวม
SELECT province, SUM(amount) AS revenue
FROM sales
WHERE month = '2026-09'
GROUP BY province
HAVING SUM(amount) > 400
ORDER BY revenue DESC;

```
```
province  revenue
 Bangkok      540
```

## q08.sql
```sql
-- Pivot ด้วย Conditional Aggregation: province เป็นแถว เดือนเป็นคอลัมน์
SELECT province,
       SUM(CASE WHEN month = '2026-08' THEN amount ELSE 0 END) AS aug,
       SUM(CASE WHEN month = '2026-09' THEN amount ELSE 0 END) AS sep,
       SUM(amount) AS total
FROM sales
GROUP BY province
ORDER BY province;

```
```
province  aug  sep  total
 Bangkok  310  540    850
Chonburi  180  360    540
```

## q09.sql
```sql
-- Subtotal + Grand total ด้วย UNION ALL (ถ้านำทุกแถวมาบวกอีกรอบจะได้ยอด x2 เพราะนับซ้ำ)
SELECT month, SUM(amount) AS revenue FROM sales GROUP BY month
UNION ALL
SELECT 'ALL', SUM(amount) FROM sales;

```
```
  month  revenue
2026-08      490
2026-09      900
    ALL     1390
```

## q10.sql
```sql
-- AOV = SUM(amount)/COUNT(DISTINCT order_id) (บาท/ออเดอร์) เทียบ AVG(amount) (บาท/รายการสินค้า)
SELECT SUM(amount) AS revenue,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(1.0 * SUM(amount) / COUNT(DISTINCT order_id), 2) AS aov,
       ROUND(AVG(amount), 2) AS avg_line
FROM sales;

```
```
 revenue  orders    aov  avg_line
    1390       6 231.67    173.75
```

## q11.sql
```sql
-- เทียบจำนวนแถวและยอดก่อน JOIN (fact_sales) กับหลัง JOIN (view sales)
SELECT 'before_join_fact_sales' AS source, COUNT(*) AS n_rows, SUM(quantity * unit_price) AS revenue FROM fact_sales
UNION ALL
SELECT 'after_join_sales_view', COUNT(*), SUM(amount) FROM sales;

```
```
                source  n_rows  revenue
before_join_fact_sales       8     1390
 after_join_sales_view       8     1390
```

## q12.sql
```sql
-- Drill-through: เปิดรายการต้นทางของช่อง Bangkok x 2026-09
SELECT order_id, line_no, product_name, quantity, amount
FROM sales
WHERE province = 'Bangkok' AND month = '2026-09'
ORDER BY order_id, line_no;

```
```
order_id  line_no product_name  quantity  amount
   O1005        1          Tea         6     300
   O1006        1       Cookie         3     240
```

## PRAGMA foreign_key_check
`ว่าง = ไม่มี FK หาย`

## oltp_demo.py
```
Before: [('O1004', 'PENDING')]
UPDATE rowcount = 1
After: [('O1004', 'PAID')]

```

## oltp_demo.py
```
Before: [('O1004', 'PAID')]
UPDATE rowcount = 0
After: [('O1004', 'PAID')]

```

## pivot_student.py
```
  order_id  line_no   full_date  year  ...   region quantity unit_price amount
0    O1001        1  2026-08-08  2026  ...     East        2         50    100
1    O1001        2  2026-08-08  2026  ...     East        1         80     80
2    O1002        1  2026-08-09  2026  ...  Central        3         50    150
3    O1003        1  2026-08-10  2026  ...  Central        2         80    160
4    O1004        1  2026-09-09  2026  ...     East        4         50    200

[5 rows x 13 columns]

P1 province x month
 month     2026-08  2026-09  Total
province                         
Bangkok       310      540    850
Chonburi      180      360    540
Total         490      900   1390

P2 September category x province
 province  Bangkok  Chonburi
category                   
Drink         300       200
Snack         240       160

assert ผ่าน: grand total = 1390 | September = 900

WRONG (default mean)
 month     2026-08  2026-09
province                  
Bangkok     155.0    270.0
Chonburi     90.0    180.0
Bangkok Sep (mean) = 270.0 <- (300+240)/2 = ค่าเฉลี่ยต่อรายการสินค้า ไม่ใช่ยอดรวม

Drink only
 month     2026-08  2026-09  Total
province                         
Bangkok       150      300    450
Chonburi      100      200    300
Total         250      500    750 
Drink total = 750

บันทึกไฟล์ใน /home/claude/dw_exam_kit/02_week09_olap_sqlite/submission

```

## challenge.py
```
====================================================================== 
ก. extended.db
KPI
 line_count  order_count  revenue
       3649         1800   807955 

Top 3 สาขา
  store_name   province  revenue  orders
      Nimman Chiang Mai   145280     317
     Pattaya   Chonburi   141215     319
Muang Rayong     Rayong   136710     293 

AOV รายเดือน
  month  revenue  orders    aov
2026-08   273650     603 453.81
2026-09   270160     586 461.02
2026-10   264145     611 432.32 

AOV ทั้งช่วง (ถ่วงน้ำหนักด้วยจำนวนออเดอร์) vs ค่าเฉลี่ยของ AOV รายเดือน (ไม่ถ่วง)
 aov_whole_period  avg_of_monthly_aov
           448.86              449.05 

-> สองค่าไม่เท่ากันเพราะ AOV เป็น non-additive: ค่าเฉลี่ยของ AOV ให้น้ำหนักทุกเดือนเท่ากัน
   ทั้งที่จำนวนออเดอร์แต่ละเดือนไม่เท่ากัน ต้องคำนวณใหม่จาก SUM(amount)/COUNT(DISTINCT order_id)

Top category ต่อ region (Window)
 region category    rev
Central    Snack 106230
   East    Drink 162060
  North    Drink  57160 

====================================================================== 
ข. challenge.db
 n_rows  n_orders  revenue
      8         6     1390 

FK check (ว่าง = ผ่าน): []
 n_rows  n_orders  revenue
     11         8     1900 

 src  n  rev
fact 11 1900
view 11 1900 

month     2026-08  2026-09  2026-10  Total
province                                  
Bangkok       310      540      200   1050
Chonburi      180      360      310    850
Total         490      900      510   1900

ยอดเพิ่ม = 3*50 + 2*80 + 4*50 = 510 บาท -> รวม 1900

```
