# DW Exam Kit — รันครั้งเดียวได้ผลทุกข้อ

## ติดตั้งครั้งเดียว (Windows PowerShell / macOS / Linux)
```
python -m pip install duckdb pandas openpyxl
```
(macOS ใช้ `python3`) ถ้าห้องสอบลง pip ไม่ได้: ใช้ DuckDB CLI (`winget install DuckDB.cli`) หรือ https://shell.duckdb.org แทน ดูหัวข้อ "ไม่มี Python"

## รันทุกอย่าง
```
python RUN_EVERYTHING.py
```
หรือรันทีละส่วน:

| โฟลเดอร์ | คำสั่ง | ได้อะไร |
|---|---|---|
| `01_coast_cafe_duckdb/` | `python run_all.py` | แลป Coast Café ครบ A1–A8, B1–B3, C1–C3, D + OLAP 17 แบบ + Summary table → `output/RESULTS.md`, `results.xlsx`, CSV ทุกข้อ |
| `02_week09_olap_sqlite/` | `python run_all_week09.py` | q01–q12, OLTP guarded update, pandas pivot P1–P4, challenge ก/ข → `submission/` |
| `03_week10_summary_mysql/` | วางไฟล์ `week10_summary_table_mysql.sql` ในแท็บ SQL ของ phpMyAdmin แล้วกด Go | ข้อ 1–10 ครบ (ทดสอบบน MariaDB 10.11 แล้ว) + trigger/procedure/event เสริม |
| `04_templates/` | `python auto_star_schema.py ...` | **ข้อมูลชุดใหม่ในห้องสอบ** → สร้าง Star Schema + DDL + แผนภาพ + Roll-up/Drill/Slice/Pivot/Top-N อัตโนมัติ |

## เจอข้อมูลใหม่ในห้องสอบ ทำแบบนี้
1. ดูคอลัมน์ก่อน: `duckdb -c "DESCRIBE SELECT * FROM 'file.csv'"` (หรือ `pd.read_csv(...).info()`)
2. ไฟล์เดียวแบน ๆ:
```
python 04_templates/auto_star_schema.py --source new.csv --date order_date --order-id order_id ^
   --dim product:product_id,product_name,category --dim customer:customer_id,province ^
   --measure qty --measure amount --out exam_out
```
   (macOS/Linux ใช้ `\` แทน `^` ต่อบรรทัด หรือพิมพ์บรรทัดเดียว)
3. หลายไฟล์ให้ JOIN ใน `--source-sql "SELECT ... FROM read_csv_auto('a.csv') JOIN read_csv_auto('b.csv') USING (id)"` ดูตัวอย่างหัวไฟล์ auto_star_schema.py
4. มีสถานะ/ส่วนลด: `--filter "status='Completed'" --derive "net_sales = quantity*unit_price*(1-discount_pct/100.0)"`
5. โจทย์ SQL เฉพาะ: เปิด `04_templates/sql_patterns_all_dialects.sql` คัดลอก pattern แล้วแทนชื่อคอลัมน์ (มีตารางแปลง DuckDB/SQLite/MySQL)
6. อีกทางที่เร็ว: คัดลอก `coast_cafe_all.sql` แล้วแก้ชื่อตาราง/คอลัมน์ แล้ว `python run_all.py my.sql` (runner ใช้กับไฟล์ SQL ใดก็ได้ที่มี `-- @@ ชื่อ | คำอธิบาย` แบ่งข้อ)

## ไม่มี Python
- DuckDB CLI: เปิด PowerShell ในโฟลเดอร์ `01_coast_cafe_duckdb` → `duckdb coast_cafe.duckdb` → `.read coast_cafe_all.sql`
- DuckDB Web Shell: ไฟล์ CSV ต้องอัปโหลดเข้า shell ก่อน แล้ววาง SQL ทีละข้อ

## ไฟล์อ่านประกอบ
- `CHEATSHEET_TH.md` — แนวข้อสอบ + ทฤษฎี (OLTP/OLAP, Grain, Star schema, Measure, Summary table, Data quality, AI features) + คำตอบข้อเขียน C3/D พร้อมตัวเลขจริง
- `01_coast_cafe_duckdb/star_schema_coast_cafe.png` — แผนภาพ Star Schema
- `01_coast_cafe_duckdb/output/RESULTS.md` — SQL + ผลลัพธ์ทุกข้อ (มีมาให้แล้ว ไม่ต้องรันก็เปิดดูได้)

## ตัวเลขตรวจสอบเร็ว (ถ้ารันแล้วได้ตรงนี้ = ถูก)
- Coast Café: orders 240 / Completed 225 / net_sales รวม **37,580.25** / ก.ค. 13,763.95 · ส.ค. 11,479.65 · ก.ย. 12,336.65
- Week 9: 8 รายการ / 6 ออเดอร์ / 23 ชิ้น / **1,390** บาท / AOV 231.67
- Week 10: 30 แถว / 14,566.00 → หลังเพิ่ม sale 31 และ refresh = 15,566.00 (31 รายการ, 56 ชิ้น)
