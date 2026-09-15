"""Bonus B: copy warehouse.db to challenge.db, add a new date and 3 new order lines,
then compare row/order counts and totals before and after the JOIN."""
from pathlib import Path
import shutil
import sqlite3

ROOT = Path(__file__).resolve().parent
SRC = ROOT / 'data' / 'warehouse.db'
DST = ROOT / 'data' / 'challenge.db'

if DST.exists():
    DST.unlink()
shutil.copy(SRC, DST)

con = sqlite3.connect(DST)
con.execute('PRAGMA foreign_keys=ON')

# New date dimension row: 2026-10-01
con.execute(
    "INSERT INTO dim_date (date_key, full_date, year, month) VALUES (?,?,?,?)",
    (20261001, '2026-10-01', 2026, '2026-10'),
)

# product_key 1=Tea (50 baht), 2=Cookie (80 baht)
# store_key   1=Bangsaen/Chonburi, 2=Siam/Bangkok
new_lines = [
    ('O1007', 1, 20261001, 1, 1, 3, 50),   # Tea x3, Chonburi
    ('O1007', 2, 20261001, 2, 1, 2, 80),   # Cookie x2, Chonburi
    ('O1008', 1, 20261001, 1, 2, 4, 50),   # Tea x4, Bangkok
]
con.executemany(
    'INSERT INTO fact_sales (order_id, line_no, date_key, product_key, store_key, quantity, unit_price) '
    'VALUES (?,?,?,?,?,?,?)',
    new_lines,
)

fk_errors = con.execute('PRAGMA foreign_key_check').fetchall()
if fk_errors:
    con.rollback()
    raise SystemExit(f'FK check failed, rolled back: {fk_errors}')

con.commit()
print('FK check after insert:', con.execute('PRAGMA foreign_key_check').fetchall())

before = con.execute(
    'SELECT COUNT(*) AS line_count, COUNT(DISTINCT order_id) AS order_count, '
    'SUM(quantity*unit_price) AS revenue FROM fact_sales'
).fetchone()
after = con.execute(
    'SELECT COUNT(*) AS line_count, COUNT(DISTINCT order_id) AS order_count, '
    'SUM(amount) AS revenue FROM sales'
).fetchone()
print('Before JOIN (fact_sales):', before)
print('After JOIN (sales):', after)

con.close()
