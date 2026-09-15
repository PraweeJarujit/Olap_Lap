# แลป OLTP OLAP และ Pivot Table — ส่งงาน

**ชื่อ:** ประวีณ์ จารุจิตร **รหัสนิสิต:** 67160349

## โครงสร้างไฟล์

```
67160349_olap_lab/
├── README.md                       ไฟล์นี้
├── report.md                       รายงานคำตอบฉบับเต็ม (ตาม Answer_Template.md)
│
├── oltp_demo.py                    ภารกิจ 1: UPDATE สถานะออเดอร์แบบมี guard (WHERE order_id + status)
├── q01.sql – q12.sql               ภารกิจ 2–5: OLAP query แต่ละข้อ (รันบน data/warehouse.db)
├── pivot_student.py                ภารกิจ 4: Pivot ด้วย pandas (P1–P4 + ทดลอง bug ไม่ใส่ aggfunc)
├── pivot_province_month.csv        ผล P1 (province x month, sum, margins)
├── pivot_september.csv             ผล P2 (September: category x province)
├── pivot_drink_only.csv            Pนขั้นตอน Excel (เครื่องไม่มี Excel)
│
├── extended_a1_top_stores.sql      โขาย (extended.db)
├── extended_a2_monthly_aov.sql     โจทย์ต่อยอด ก.: AOV รายเดือน (extended.db)
├── extended_a3_overall_aov.sql     โจทย์ต่อยอด ก.: AOV รวมทั้งช่วง (extended.db)
├── challenge.py                    โจทย์ต่อยอด ข.: สร้าง challenge.db (คัดลอกจาก warehouse.db + เพิ่ม 3 บรรทัด
 2026-10-01)
├── extended_b_challenge_pivot.sql  โจทย์ต่อยอด ข.: Pivot ใหม่บน challenge.db
│
└── results/                        ผลรันจริงของทุกไฟล์ข้างบน (.txt / .csv) เก็บไว้เป็นหลักฐาน
```

## วิธีรันซ้ำ (ถ้าต้องการตรวจสอบ)

ไฟล์เหล่านี้อ้างอิง `data/warehouse.db`, `data/extended.db`, `data/challenge.db` ซึ่งไม่ได้แนบมาด้วย (ตามคำสั่งในใบงา
นว่าไม่ต้องส่งฐานข้อมูลต้นฉบับ) หากต้องการรันซ้ำไปไว้ในโฟลเดอร์ `week09/` (ระดับเดียวกับ `l
ab.py`, `query.py`) แล้วรัน:

```bash
python -m pip install -r requirements.txt
python lab.py                                   # สร้าง data/warehouse.db, extended.db, oltp.db

python oltp_demo.py                             # ภารกิจ 1 (รัน 2 รอบเพื่อดู rowcount ต่างกัน)
python query.py data/warehouse.db q01.sql        # ทำซ้ำกับ q02.sql – q12.sql
python pivot_student.py                          # ภารกิจ 4

python query.py data/extended.db extended_a1_top_stores.sql
python query.py data/extended.db exte
python query.py data/extended.db extended_a3_overall_aov.sql

python challenge.py                              # สร้าง data/challenge.db (โจทย์ต่อยอด ข.)
python query.py data/challenge.db ext
```

## คำตอบและคำอธิบาย

คำตอบของทุกกิจกรรม (รวมคำถามระหว่างทำ, จุดตรวจ, และโจทย์ต่อยอด) อยู่ใน [`report.md`](./report.md) ครบทั้ง 6 ส่วนตาม
 Answer_Template.md
