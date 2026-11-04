"""ภารกิจ 1 OLTP: เปลี่ยน O1004 PENDING -> PAID แบบมีเงื่อนไข (guarded UPDATE)
รัน: python oltp_demo.py          (รันสองครั้ง: รอบแรก rowcount=1, รอบสอง rowcount=0)
     python oltp_demo.py --reset  (คืนสถานะเป็น PENDING เพื่อทดลองใหม่)
"""
from pathlib import Path
import sqlite3, sys

p = Path(__file__).resolve().parent / 'data' / 'oltp.db'
if not p.exists():
    raise SystemExit('Run lab.py first')

with sqlite3.connect(p) as con:
    if '--reset' in sys.argv:
        con.execute("UPDATE orders SET status='PENDING' WHERE order_id='O1004'")
        print('Reset O1004 -> PENDING')
    print('Before:', con.execute('SELECT * FROM orders').fetchall())
    cur = con.execute(
        "UPDATE orders SET status = 'PAID' WHERE order_id = ? AND status = 'PENDING'",
        ('O1004',))
    print('UPDATE rowcount =', cur.rowcount)   # รอบแรก 1, รอบสอง 0
    con.commit()                               # with-block ก็ commit ให้อัตโนมัติ
    print('After:', con.execute('SELECT * FROM orders').fetchall())

# คำตอบ:
# - รอบแรกแก้ 1 แถว (PENDING -> PAID) รอบสองแก้ 0 แถว เพราะเงื่อนไข status='PENDING' ไม่จริงแล้ว
# - เงื่อนไข status กันการทำธุรกรรมซ้ำ (idempotent) เช่นลูกค้ากดจ่ายสองครั้ง / ไม่ให้ย้อนสถานะ CANCELLED เป็น PAID
# - เป็น OLTP เพราะเป้าหมายคือเขียน/แก้สถานะปัจจุบันของธุรกรรมเดียว (แม้มี SELECT ก็เป็นการอ่านรายการเฉพาะ)
# - oltp.db เปลี่ยน แต่ warehouse.db ไม่เปลี่ยนทันที เพราะเป็นคนละฐาน ต้องมี ETL/ELT (batch หรือ CDC)
#   ย้ายข้อมูลเข้าคลัง และรายงานควรแสดงเวลาอัปเดตล่าสุด (data latency)
