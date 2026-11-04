-- =====================================================================
-- SQL PATTERNS สำหรับข้อสอบ Data Warehouse — แทนชื่อใน <...> แล้วรันได้เลย
-- ใช้ได้กับ DuckDB เป็นหลัก มีบรรทัด [SQLite] / [MySQL] กำกับเมื่อไวยากรณ์ต่างกัน
-- =====================================================================

-- ---------- 0) ตารางแปลงคำสั่งที่ต่างกันระหว่างฐานข้อมูล ----------
-- เดือน 'YYYY-MM'   DuckDB: strftime(d,'%Y-%m')  | SQLite: strftime('%Y-%m', d) | MySQL: DATE_FORMAT(d,'%Y-%m')
-- ตัดเป็นต้นเดือน    DuckDB/Postgres: DATE_TRUNC('month', d)               | MySQL: DATE_FORMAT(d,'%Y-%m-01')
-- ปี / เดือน         DuckDB: year(d), month(d) | SQLite: CAST(strftime('%Y',d) AS INT) | MySQL: YEAR(d), MONTH(d)
-- ต่างกันกี่วัน       DuckDB: DATE_DIFF('day', a, b) | SQLite: julianday(b)-julianday(a) | MySQL: DATEDIFF(b, a)
-- หารให้ได้ทศนิยม    SQLite ต้องคูณ 1.0 ก่อน: 1.0*SUM(x)/COUNT(*)  (DuckDB/MySQL หารทศนิยมให้เอง)
-- อ่าน CSV          DuckDB: SELECT * FROM read_csv_auto('file.csv')  | SQLite: .import --csv file.csv t | MySQL: LOAD DATA / phpMyAdmin Import
-- ส่งออก CSV         DuckDB: COPY (SELECT ...) TO 'out.csv' (HEADER) | SQLite: .mode csv + .output out.csv
-- QUALIFY           มีใน DuckDB เท่านั้น — SQLite/MySQL ให้ห่อ subquery แล้ว WHERE rnk = 1
-- PIVOT             มีใน DuckDB เท่านั้น — ที่อื่นใช้ SUM(CASE WHEN ...)
-- ROLLUP            DuckDB/Postgres: GROUP BY ROLLUP(a,b) | MySQL: GROUP BY a,b WITH ROLLUP | SQLite: ไม่มี → UNION ALL

-- ---------- 1) Profiling ----------
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT <id>) AS n_distinct_id,
       MIN(<date>) AS min_date, MAX(<date>) AS max_date,
       SUM(CASE WHEN <col> IS NULL THEN 1 ELSE 0 END) AS n_null_col
FROM <table>;
SELECT <status>, COUNT(*) FROM <table> GROUP BY <status>;           -- ดูค่าที่เป็นไปได้

-- ---------- 2) Grain check: COUNT(*) vs COUNT(DISTINCT) vs SUM ----------
SELECT COUNT(*) AS line_count, COUNT(DISTINCT <order_id>) AS order_count,
       SUM(<qty>) AS units, SUM(<amount>) AS revenue
FROM <fact>;

-- ---------- 3) Roll-up / Drill-down / Slice / Dice / HAVING ----------
SELECT <month_expr> AS month, SUM(<amount>) AS revenue FROM <v> GROUP BY 1 ORDER BY 1;                 -- roll-up
SELECT <month_expr> AS month, <dim>, SUM(<amount>) FROM <v> GROUP BY 1, 2 ORDER BY 1, 2;              -- drill-down (เพิ่มมิติ)
SELECT <date>, SUM(<amount>) FROM <v> WHERE <month_expr> = '2026-09' GROUP BY 1 ORDER BY 1;          -- drill-down ในมิติเวลา
SELECT <dim>, SUM(<amount>) FROM <v> WHERE <month_expr> = '2026-09' GROUP BY 1;                       -- slice (1 เงื่อนไข)
SELECT <dim>, SUM(<amount>) FROM <v>
WHERE <month_expr> = '2026-09' AND <category> = 'X' AND <province> IN ('A','B') GROUP BY 1;          -- dice (หลายเงื่อนไข)
SELECT <dim>, SUM(<amount>) AS revenue FROM <v>
WHERE <month_expr> = '2026-09' GROUP BY <dim> HAVING SUM(<amount>) > 400 ORDER BY revenue DESC;      -- WHERE แถว / HAVING กลุ่ม
SELECT * FROM <v> WHERE <dim> = 'A' AND <month_expr> = '2026-09';                                    -- drill-through

-- ---------- 4) Pivot ----------
SELECT <row_dim>,
       SUM(CASE WHEN <col_dim> = 'v1' THEN <amount> ELSE 0 END) AS v1,
       SUM(CASE WHEN <col_dim> = 'v2' THEN <amount> ELSE 0 END) AS v2,
       SUM(<amount>) AS total
FROM <v> GROUP BY <row_dim> ORDER BY <row_dim>;
-- DuckDB:  PIVOT <v> ON <col_dim> USING SUM(<amount>) GROUP BY <row_dim>;
-- UNPIVOT (DuckDB): UNPIVOT <pivoted> ON v1, v2 INTO NAME <col_dim> VALUE <amount>;

-- ---------- 5) Subtotal / Grand total ----------
SELECT <dim>, SUM(<amount>) FROM <v> GROUP BY <dim>
UNION ALL SELECT 'ALL', SUM(<amount>) FROM <v>;
SELECT <a>, <b>, SUM(<amount>), GROUPING(<a>, <b>) FROM <v> GROUP BY ROLLUP(<a>, <b>);   -- DuckDB/Postgres
SELECT <a>, <b>, SUM(<amount>) FROM <v> GROUP BY <a>, <b> WITH ROLLUP;                     -- [MySQL]
SELECT <a>, <b>, SUM(<amount>) FROM <v> GROUP BY CUBE(<a>, <b>);                           -- ทุกการรวม
SELECT <a>, <b>, SUM(<amount>) FROM <v> GROUP BY GROUPING SETS ((<a>), (<b>), ());          -- เลือกชุดเอง

-- ---------- 6) TOP-N / TOP-N ต่อกลุ่ม ----------
SELECT <dim>, SUM(<amount>) AS revenue FROM <v> GROUP BY <dim> ORDER BY revenue DESC LIMIT 5;
SELECT * FROM (
    SELECT <grp>, <dim>, SUM(<amount>) AS revenue,
           RANK() OVER (PARTITION BY <grp> ORDER BY SUM(<amount>) DESC) AS rnk
    FROM <v> GROUP BY <grp>, <dim>
) t WHERE rnk <= 3 ORDER BY <grp>, rnk;          -- ทำงานใน SQLite 3.25+/MySQL 8/DuckDB

-- ---------- 7) % ของทั้งหมด / MoM / ยอดสะสม / Moving average ----------
SELECT <dim>, SUM(<amount>) AS revenue,
       ROUND(100.0 * SUM(<amount>) / SUM(SUM(<amount>)) OVER (), 2) AS pct_total
FROM <v> GROUP BY <dim>;
WITH m AS (SELECT <month_expr> AS month, SUM(<amount>) AS rev FROM <v> GROUP BY 1)
SELECT month, rev, LAG(rev) OVER (ORDER BY month) AS prev,
       ROUND(100.0 * (rev - LAG(rev) OVER (ORDER BY month)) / LAG(rev) OVER (ORDER BY month), 2) AS mom_pct,
       SUM(rev) OVER (ORDER BY month) AS running_total
FROM m;
WITH d AS (SELECT <date> AS dt, SUM(<amount>) AS s FROM <v> GROUP BY 1)
SELECT dt, s, AVG(s) OVER (ORDER BY dt ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS ma7_rows FROM d;
-- 7 วันจริง (DuckDB): ... OVER (ORDER BY dt RANGE BETWEEN INTERVAL 6 DAYS PRECEDING AND CURRENT ROW)
-- หรือสร้าง date spine: generate_series(min, max, INTERVAL 1 DAY) แล้ว LEFT JOIN + COALESCE(s,0)

-- ---------- 8) AOV (non-additive) ----------
SELECT SUM(<amount>) / COUNT(DISTINCT <order_id>) AS aov,  -- บาท/ออเดอร์
       AVG(<amount>) AS avg_line                            -- บาท/รายการสินค้า (คนละตัวชี้วัด)
FROM <v>;

-- ---------- 9) Data quality ----------
SELECT * FROM <fact> f WHERE NOT EXISTS (SELECT 1 FROM <dim> d WHERE d.<key> = f.<key>);   -- FK หาย (orphan)
SELECT f.* FROM <fact> f LEFT JOIN <dim> d ON f.<key> = d.<key> WHERE d.<key> IS NULL;     -- แบบ LEFT JOIN
SELECT <id>, COUNT(*) FROM <t> GROUP BY <id> HAVING COUNT(*) > 1;                          -- คีย์ซ้ำ
SELECT * FROM <t> WHERE <qty> IS NULL OR <qty> <= 0;                                        -- ค่าไม่สมเหตุสมผล
SELECT 'before' s, COUNT(*), SUM(<amount>) FROM <fact>
UNION ALL SELECT 'after_join', COUNT(*), SUM(<amount>) FROM <fact> JOIN <dim> USING (<key>); -- JOIN fan-out?

-- ---------- 10) RFM features ----------
SELECT <customer_id>,
       MAX(<date>)                AS last_order,
       COUNT(DISTINCT <order_id>) AS frequency,
       SUM(<amount>)              AS monetary
FROM <fact> GROUP BY <customer_id>;

-- ---------- 11) Star schema DDL (generic) ----------
CREATE TABLE dim_<x> (<x>_key INTEGER PRIMARY KEY, <x>_id VARCHAR UNIQUE, <attr> VARCHAR);
CREATE TABLE fact_<y> (
    <order_id> VARCHAR, line_no INTEGER,
    date_key INTEGER REFERENCES dim_date(date_key),
    <x>_key INTEGER REFERENCES dim_<x>(<x>_key),
    quantity INTEGER CHECK (quantity > 0), amount DECIMAL(12,2),
    PRIMARY KEY (<order_id>, line_no)
);
-- Surrogate key จาก natural key:
CREATE TABLE dim_<x> AS SELECT ROW_NUMBER() OVER (ORDER BY <x>_id) AS <x>_key, * FROM (SELECT DISTINCT <x>_id, <attr> FROM <staging>);

-- ---------- 12) Summary table + refresh ----------
CREATE TABLE agg_<name> AS SELECT <grain_cols>, SUM(<amount>) revenue, SUM(<qty>) qty, COUNT(*) n FROM <fact> GROUP BY <grain_cols>;
DELETE FROM agg_<name> WHERE <month_col> = '<month>';                                         -- incremental
INSERT INTO agg_<name> SELECT <grain_cols>, SUM(<amount>), SUM(<qty>), COUNT(*) FROM <fact> WHERE <month filter> GROUP BY <grain_cols>;

-- ---------- 13) SCD Type 2 (เผื่อออกทฤษฎี) ----------
-- dim_customer(customer_key, customer_id, province, valid_from, valid_to, is_current)
UPDATE dim_customer SET valid_to = CURRENT_DATE, is_current = FALSE
WHERE customer_id = '<id>' AND is_current = TRUE;
INSERT INTO dim_customer VALUES (<new_key>, '<id>', '<new_province>', CURRENT_DATE, DATE '9999-12-31', TRUE);
