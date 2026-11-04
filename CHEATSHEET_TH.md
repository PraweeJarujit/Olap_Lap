# Data Warehouse — ชีทสรุปสอบ + แนวข้อสอบ + คำตอบข้อเขียน

## 1. แนวข้อสอบที่น่าจะออก (เรียงจากโอกาสสูง → ต่ำ)

| # | แนวโจทย์ | ดูจากไหน | ไฟล์ในชุดนี้ |
|---|---|---|---|
| 1 | **เขียน SQL วิเคราะห์ยอดขาย**: SELECT/WHERE/GROUP BY/JOIN/HAVING/TOP-N (Coast Café Part A) | lab_handout ทั้ง Part A เป็นคะแนน 40% | `01_coast_cafe_duckdb/coast_cafe_all.sql` ข้อ A1–A8 |
| 2 | **OLAP operation**: บอกชื่อ + เขียน SQL ของ Roll-up / Drill-down / Slice / Dice / Pivot / Drill-through | สไลด์ OLAP หน้า 17–28 | q02–q12, O1–O17 |
| 3 | **ออกแบบ Star Schema**: ระบุ Grain, Fact, Dimension, Measure, PK/FK, Hierarchy, วาดรูป | สไลด์ 10–16, Part B1 | `star_schema_coast_cafe.png`, B1_dims/B1_fact |
| 4 | **Grain / การนับ**: COUNT(*) vs COUNT(DISTINCT) vs SUM, AOV vs AVG | สไลด์ 12–14, 34–35 | q01, q10, O15 |
| 5 | **หาข้อผิด**: pivot ลืม `aggfunc` (ได้ mean), WHERE vs HAVING, บวก Total ซ้ำ, JOIN แล้วยอดเพิ่ม | สไลด์ 24, 28, 31–32 | pivot_student.py, q07, q09, q11 |
| 6 | **Summary/Aggregate table**: Grain, PK, Validation, Data stale, Refresh | Lab week 10 | `03_week10_summary_mysql/`, T1–T7 |
| 7 | **Data Mart / Data Quality** | Part B2–B3, week05/06/08 | B2, B3_* |
| 8 | **Window function / Feature สำหรับ AI**: MA7, RFM, Data leakage | Part C | C1, C1_calendar, C2, C3_feature_table |
| 9 | **OLTP vs OLAP** (จับคู่งาน / ข้อเขียน) | สไลด์ 3–9 | ข้อ 2 ด้านล่าง |
| 10 | **Executive insight** สั้น ๆ จากผล SQL | Part D | ข้อ 7 ด้านล่าง |

> สังเกต: ทุกแลปของอาจารย์ใช้รูปแบบ "เขียน SQL → แนบผล → อธิบาย 3–5 บรรทัด" และเน้น **ตรวจยอดกลับ** (ยอดรวมย่อยต้องเท่ายอดรวมใหญ่) — ข้อสอบน่าจะให้คะแนนส่วนอธิบายด้วย ไม่ใช่แค่โค้ด

---

## 2. OLTP vs OLAP

| | OLTP | OLAP |
|---|---|---|
| เป้าหมาย | ทำธุรกรรมประจำวัน | วิเคราะห์เพื่อตัดสินใจ |
| การเข้าถึง | อ่าน/เขียนทีละรายการ (INSERT/UPDATE) | อ่านและสรุปหลายรายการ (GROUP BY) |
| ข้อมูล | สถานะปัจจุบัน | ย้อนหลังหลายช่วงเวลา |
| แบบจำลอง | Normalized (3NF) | Star schema / semantic model |
| ตัวอย่าง | อัปเดตสถานะชำระเงิน, ตัดสต็อก, ดูว่าออเดอร์ O1004 จ่ายแล้วหรือยัง | ยอดขายรายเดือนแยกจังหวัด |

- จำจาก **เป้าหมายของงาน** ไม่ใช่คำสั่ง SQL (SELECT ก็เป็น OLTP ได้ถ้าอ่านรายการเดียวเพื่อทำธุรกรรม)
- OLTP → **ETL/ELT** → Data Warehouse → OLAP/Pivot; ข้อมูลในคลังมีความหน่วง ควรแสดงเวลาอัปเดตล่าสุด
- Guarded UPDATE: `UPDATE orders SET status='PAID' WHERE order_id='O1004' AND status='PENDING'` รอบแรกแก้ 1 แถว รอบสองแก้ 0 แถว → กันการทำธุรกรรมซ้ำ (idempotent)

## 3. Multidimensional model

- **Measure** = ค่าที่วัด (ยอดขาย, จำนวนชิ้น) · **Dimension** = มุมมอง (เวลา, สินค้า, สถานที่, ลูกค้า, ช่องทาง)
- **Grain** = 1 แถวของ fact หมายถึงอะไร ต้องประกาศก่อนออกแบบ เช่น "1 แถว = 1 รายการสินค้าใน 1 ออเดอร์" PK = (order_id, line_no)
  - Coast Café: 1 แถว = 1 ออเดอร์ (order_id ไม่ซ้ำ มีสินค้าเดียว) → COUNT(*) = จำนวนออเดอร์พอดี
  - week09: 8 แถว แต่ 6 ออเดอร์ → นับออเดอร์ต้องใช้ `COUNT(DISTINCT order_id)`
- **Hierarchy**: เวลา ปี > ไตรมาส > เดือน > วัน · สถานที่ ภาค > จังหวัด > สาขา · สินค้า หมวด > สินค้า
- **Star schema**: fact ตรงกลาง + dimension รอบ ๆ ความสัมพันธ์ dim 1 : N fact; fact มี FK + measures; dim มี PK (surrogate key) + attributes
- **Snowflake**: dimension ถูก normalize แตกต่อ (เช่น product → category) ประหยัดที่แต่ JOIN มากขึ้น
- **Surrogate key** (เลขรันที่คลังสร้างเอง) vs **Natural key** (รหัสจากระบบต้นทาง) — ใช้ surrogate เพื่อรองรับ SCD และไม่ผูกกับระบบต้นทาง
- **Degenerate dimension** = order_id ที่อยู่ใน fact โดยไม่มีตาราง dim
- **Fact ประเภท**: Transaction (ต่อรายการ), Periodic snapshot (สต็อกสิ้นวัน), Accumulating snapshot (ติดตามขั้นตอนออเดอร์)
- **SCD**: Type 1 เขียนทับ · Type 2 เพิ่มแถวใหม่ + valid_from/valid_to/is_current (เก็บประวัติ) · Type 3 เพิ่มคอลัมน์ค่าเดิม

### Star Schema Coast Café
ดูรูป `01_coast_cafe_duckdb/star_schema_coast_cafe.png`
```
              dim_date(date_key PK)        dim_customer(customer_key PK, customer_id, name, province, segment)
                         \                    /
                          fact_sales (order_id, date_key FK, customer_key FK, product_key FK, channel_key FK,
                          /           quantity, unit_price, discount_pct, gross_sales, net_sales, gross_profit)
     dim_product(product_key PK, product_id, name, category, list_price, unit_cost)    dim_channel(channel_key PK, channel)
```
คำอธิบาย 3–5 บรรทัด: Fact เก็บยอดขายที่ Grain 1 ออเดอร์ที่สถานะ Completed มี measure คือ quantity, net_sales (และ gross_profit) เชื่อมกับ 4 มิติผ่าน surrogate key: date_key (YYYYMMDD), customer_key, product_key, channel_key แต่ละมิติสัมพันธ์ 1:N กับ fact ทำให้ตอบคำถาม "ยอดขาย ตามเวลา/ลูกค้า/สินค้า/ช่องทาง" ได้ด้วย JOIN ชั้นเดียว order_id เป็น degenerate dimension

## 4. OLAP operations

| Operation | ความหมาย | SQL |
|---|---|---|
| Roll-up | ลดรายละเอียด/ขึ้นระดับ hierarchy (วัน→เดือน) | GROUP BY month |
| Drill-down | เพิ่มรายละเอียด (เดือน→วัน หรือเพิ่มมิติ province) | เพิ่มคอลัมน์ใน GROUP BY |
| Slice | ตัดมิติเดียวเหลือค่าเดียว | WHERE month='2026-09' |
| Dice | เลือกช่วงหลายมิติ | WHERE หลายเงื่อนไข |
| Pivot | หมุนแกน แถว↔คอลัมน์ | SUM(CASE…)/PIVOT/pivot_table |
| Drill-through | เปิดรายการต้นทางที่ประกอบเป็นยอดสรุป | SELECT รายการ WHERE … |

- **WHERE** กรองแถวก่อนรวม · **HAVING** กรองกลุ่มหลังรวม (เงื่อนไขที่ใช้ SUM/COUNT ต้องอยู่ HAVING)
- ลำดับทำงาน: FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
- **จุดตรวจ**: roll-up ไม่ทำให้ยอดรวมเปลี่ยน; ยอดรายวันกันยายนรวมกัน = ผล slice กันยายน; drill-through รวมกัน = ช่องที่มาจาก
- Pivot ที่มีแถว/คอลัมน์ Total: ห้ามบวกทั้งตาราง (นับซ้ำ) ให้ตรวจเฉพาะเซลล์ Total×Total
- `pd.pivot_table` ไม่ใส่ `aggfunc` → ค่าเริ่มต้นคือ **mean** (Bangkok ก.ย. ได้ 270 = (300+240)/2 แทน 540)
- SQL CASE pivot ต้องรู้คอลัมน์ล่วงหน้า: เพิ่มเดือนใหม่ต้องแก้ CASE เอง; pandas `columns="month"` สร้างคอลัมน์ใหม่ให้อัตโนมัติ

## 5. ชนิดของ Measure

| ชนิด | ตัวอย่าง | วิธีรวม |
|---|---|---|
| Additive | ยอดขาย, จำนวนชิ้น | SUM ได้ทุกมิติ |
| Semi-additive | สต็อกคงเหลือสิ้นวัน, ยอดเงินในบัญชี | รวมข้ามสาขาได้ แต่ข้ามเวลาไม่ได้ (ใช้ค่าสิ้นงวด/ค่าเฉลี่ย) |
| Non-additive | AOV, %, margin, unit_price | คำนวณใหม่จากยอดรวม เช่น AOV = SUM(amount)/COUNT(DISTINCT order_id) |

- ค่าเฉลี่ยของ AOV รายเดือน ≠ AOV ทั้งช่วง (ไม่ถ่วงจำนวนออเดอร์) — extended.db: 449.05 vs 448.86
- unit_price ห้าม SUM เป็นยอดขาย (เป็นราคาต่อชิ้น ไม่ใช่เงินที่ได้)

## 6. Summary / Aggregate table (week 10)

- **Pre-aggregation**: คำนวณผลสรุปเก็บไว้ล่วงหน้า dashboard อ่านแถวน้อยกว่า (EXPLAIN: fact 30 แถว + Using temporary; filesort vs summary 15 แถว อ่านตาม PK)
- Grain ของ summary = เดือน × สินค้า → PK = (sales_month, product_id); คอลัมน์: sales_month, product_id, revenue, quantity, order_count, last_refreshed
- **Validation**: SUM(revenue) summary = SUM(amount) fact, ทั้ง revenue / quantity / order_count
- **Data stale**: INSERT ใน fact แล้ว summary ไม่เปลี่ยน เพราะเป็นตารางจริงที่คำนวณ ณ เวลาที่สร้าง ไม่ใช่ VIEW
- **Refresh**: full (TRUNCATE+INSERT), incremental (DELETE เดือนที่กระทบ + INSERT), upsert (ON DUPLICATE KEY UPDATE), trigger (สดแต่ช้าลง), scheduled event/batch (มี latency)
- VIEW = ไม่เก็บข้อมูล คำนวณทุกครั้ง (สดเสมอ ช้ากว่า) · TABLE/Materialized view = เก็บผล (เร็ว แต่ต้อง refresh)
- sale_id 31: P101 2 ชิ้น = 1,000 บาท (500/ชิ้น ปกติ 199) → ข้อมูลผิดปกติ ควร flag

## 7. Data Mart / Data Quality / ETL

- **Data Warehouse** = คลังกลางทั้งองค์กร · **Data Mart** = ชุดย่อยตามหน่วยงาน/หัวข้อ (เช่น mart_monthly_sales ของฝ่ายขาย) · **Fact** = เหตุการณ์ที่วัดได้ · **Dimension** = บริบท
- 6 มิติคุณภาพข้อมูล: Completeness, Accuracy, Consistency, Validity, Uniqueness, Timeliness
- การจัดการ: customer_id หาย → แยกไป reject หรือ map เป็น Unknown member (key = -1) ไม่ลบเงียบ · quantity ≤ 0 → reject/ตรวจว่าเป็นคืนสินค้า · product_id ไม่พบ → reject + แจ้งเจ้าของ master data · บันทึกจำนวนและเหตุผลใน data quality report
- ETL = Extract → Transform → Load (แปลงก่อนโหลด) · ELT = โหลดดิบก่อนแล้วแปลงในคลัง (ทำได้เพราะคลังสมัยใหม่ประมวลผลแรง)
- Columnar (DuckDB, BigQuery, Snowflake, Redshift) อ่านเฉพาะคอลัมน์ที่ใช้ + vectorized → เหมาะ OLAP; row store (MySQL) เหมาะ OLTP

## 8. AI Analytics (Part C)

**C1** ทำไม 7 แถว ≠ 7 วัน: `ROWS BETWEEN 6 PRECEDING` นับแถว ไม่ได้นับวัน ถ้าวันไหนไม่มีขายจะไม่มีแถว หน้าต่างจึงยืดเกิน 7 วันปฏิทินและค่าเฉลี่ยสูงเกินจริง (ไม่นับวันที่ยอด = 0) — ข้อมูลนี้มี 92 วัน มีขาย 84 วัน **ขาด 8 วัน** แก้โดยสร้าง date spine (generate_series) LEFT JOIN แล้ว COALESCE เป็น 0 หรือใช้ `RANGE BETWEEN INTERVAL 6 DAYS PRECEDING`

**C2** RFM: Recency = วันตั้งแต่ซื้อล่าสุด, Frequency = จำนวนออเดอร์, Monetary = ยอดซื้อรวม → ใช้แบ่งกลุ่ม (K-means หรือ NTILE score)

**C3 ตัวอย่างคำตอบ (คาดการณ์ยอดขายรายวัน)**
- Target: ยอดขายสุทธิรวมของวันถัดไป
- Features: lag_1, lag_7, MA7 ย้อนหลัง (ไม่รวมวันนี้), วันในสัปดาห์, weekend, เดือน, สัดส่วนช่องทาง, ส่วนลดเฉลี่ย
- ประเมินผล: แบ่ง train/test ตามเวลา (ก.ค.–ส.ค. train, ก.ย. test) ไม่สุ่ม; วัด MAE / RMSE / MAPE เทียบ baseline (ใช้ยอดเมื่อวาน หรือ MA7)
- Data leakage: ห้ามใช้ข้อมูลของวันที่ทำนาย/อนาคตเป็น feature (เช่น MA7 ที่รวมวันนี้, ยอดทั้งเดือน), ห้ามสุ่มแบ่งข้อมูลอนุกรมเวลา, ห้ามรวมออเดอร์ Cancelled ที่รู้ผลทีหลัง; ข้อมูลมีแค่ 3 เดือน 225 ออเดอร์และเป็นข้อมูลสังเคราะห์ → โมเดลไม่น่าเชื่อถือพอใช้จริง

(ทางเลือก แบ่งกลุ่มลูกค้า: Target ไม่มี (unsupervised) / Features = R,F,M,AOV,segment,province / ประเมินด้วย silhouette + ความหมายทางธุรกิจ / Leakage: คำนวณ RFM ด้วยข้อมูลหลังวันอ้างอิง)

## 9. Executive Insight (Part D) — ตัวเลขจากการรันจริง (≤150 คำ)

> **สิ่งที่พบ:** ก.ค.–ก.ย. 2026 มีออเดอร์ Completed 225 จาก 240 (ยกเลิก 15) ยอดขายสุทธิ 37,580.25 บาท เดลิเวอรีทำยอดสูงสุด 13,152.30 บาท (35%) ออนไลน์มี AOV สูงสุด 179.74 บาทแต่ยกเลิกสูงสุด 9.5% เครื่องดื่มทำรายได้ 44% (16,694.50) โกโก้ให้กำไรขั้นต้นสูงสุด 2,794 บาท ฉะเชิงเทราทำยอด 47.6% และลูกค้า Walk-in ทำยอด 67%
> **ข้อเสนอ:** ผลักดันโกโก้/ชาไทย (margin 49–53%) ผ่านเดลิเวอรี ลดการยกเลิกออนไลน์ และชวนลูกค้า Walk-in ยอดสูง (C008, C039, C031, C026) สมัคร Member
> **ข้อจำกัด:** เป็นข้อมูลสังเคราะห์ 3 เดือน ยอด ส.ค. ลด 16.6% แต่ยังสรุปสาเหตุไม่ได้ ไม่มีข้อมูลต้นทุนการส่ง/โปรโมชัน AI อาจสรุปเหตุผลเกินหลักฐาน ต้องตรวจตัวเลขกับ SQL ก่อนตัดสินใจ

ตัวเลขอื่นที่ใช้ได้: ก.ค. 13,763.95 · ส.ค. 11,479.65 (−16.6%) · ก.ย. 12,336.65 (+7.5%) · AOV รวม 167.02 · ส่วนลดรวม 1,145.75 · สินค้ายอดสูงสุด เค้กช็อกโกแลต 6,895.35 · Top ลูกค้า C008 1,734.10

## 10. คำตอบสั้นคำถามระหว่างแลป week 9

- q03 vs q04: q03 เพิ่ม **มิติใหม่** (สถานที่) → อ่านเทียบระหว่างจังหวัด; q04 ลง **ลึกในมิติเดิม** (เดือน→วัน) → อ่านแนวโน้มภายในเดือน
- q07: เดือนกรองใน WHERE, SUM(amount) > 400 กรองใน HAVING → Bangkok 540
- q12 รวมกัน (300+240 = 540) = ช่อง Bangkok × 2026-09 ใน q03
- q09: นำทุกแถวรวม ALL มาบวกอีกรอบได้ 2,780 = นับซ้ำสองเท่า
- q10: AOV 231.67 บาท/ออเดอร์ vs AVG(amount) 173.75 บาท/รายการ
- q11: ก่อน/หลัง JOIN 8 แถว 1,390 เท่ากัน — ถ้ามิติมีคีย์ซ้ำ JOIN จะขยายแถว (fan-out) ยอดเพิ่มเกินจริง; ถ้า FK หาย INNER JOIN จะตัดแถวทิ้ง ยอดหาย
- Drink filter รวม 750 บาท · Rows=province Columns=month Values=Sum(amount)
- ตัวเลขชุดหลัก: 8 รายการ / 6 ออเดอร์ / 23 ชิ้น / 1,390 บาท; ส.ค. 490, ก.ย. 900; Bangkok 850, Chonburi 540
