"""โจทย์ต่อยอด ก + ข
ก. extended.db: Top 3 สาขา, AOV รายเดือน, AOV ทั้งช่วง vs ค่าเฉลี่ยของ AOV รายเดือน
ข. challenge.db: copy warehouse.db + เพิ่มเดือนตุลาคม (O1007, O1008) แล้ว Pivot ใหม่ + ตรวจก่อน/หลัง
รัน: python challenge.py
"""
from pathlib import Path
import shutil, sqlite3
import pandas as pd

ROOT = Path(__file__).resolve().parent
DATA = ROOT / 'data'
OUT = ROOT / 'submission'
OUT.mkdir(exist_ok=True)

def q(con, sql):
    d = pd.read_sql_query(sql, con)
    print(d.to_string(index=False), '\n')
    return d

# ---------------- ก. extended.db ----------------
print('=' * 70, '\nก. extended.db')
with sqlite3.connect((DATA / 'extended.db').as_uri() + '?mode=ro', uri=True) as con:
    print('KPI'); q(con, '''SELECT COUNT(*) line_count, COUNT(DISTINCT order_id) order_count,
                              SUM(amount) revenue FROM sales''')
    print('Top 3 สาขา')
    q(con, '''SELECT store_name, province, SUM(amount) AS revenue,
                     COUNT(DISTINCT order_id) AS orders
              FROM sales GROUP BY store_name, province
              ORDER BY revenue DESC LIMIT 3''')
    print('AOV รายเดือน')
    m = q(con, '''SELECT month, SUM(amount) AS revenue, COUNT(DISTINCT order_id) AS orders,
                         ROUND(1.0*SUM(amount)/COUNT(DISTINCT order_id),2) AS aov
                  FROM sales GROUP BY month ORDER BY month''')
    print('AOV ทั้งช่วง (ถ่วงน้ำหนักด้วยจำนวนออเดอร์) vs ค่าเฉลี่ยของ AOV รายเดือน (ไม่ถ่วง)')
    q(con, '''WITH m AS (SELECT month, 1.0*SUM(amount)/COUNT(DISTINCT order_id) AS aov
                         FROM sales GROUP BY month)
              SELECT (SELECT ROUND(1.0*SUM(amount)/COUNT(DISTINCT order_id),2) FROM sales) AS aov_whole_period,
                     ROUND(AVG(aov),2) AS avg_of_monthly_aov FROM m''')
    print('-> สองค่าไม่เท่ากันเพราะ AOV เป็น non-additive: ค่าเฉลี่ยของ AOV ให้น้ำหนักทุกเดือนเท่ากัน\n'
          '   ทั้งที่จำนวนออเดอร์แต่ละเดือนไม่เท่ากัน ต้องคำนวณใหม่จาก SUM(amount)/COUNT(DISTINCT order_id)\n')
    print('Top category ต่อ region (Window)')
    q(con, '''WITH rc AS (SELECT region, category, SUM(amount) rev FROM sales GROUP BY region, category)
              SELECT region, category, rev FROM (
                SELECT *, RANK() OVER (PARTITION BY region ORDER BY rev DESC) rk FROM rc) WHERE rk=1''')

# ---------------- ข. challenge.db ----------------
print('=' * 70, '\nข. challenge.db')
dst = OUT / 'challenge.db'
shutil.copy(DATA / 'warehouse.db', dst)
con = sqlite3.connect(dst)
con.execute('PRAGMA foreign_keys = ON')
before = q(con, 'SELECT COUNT(*) n_rows, COUNT(DISTINCT order_id) n_orders, SUM(amount) revenue FROM sales')
try:
    con.execute("INSERT INTO dim_date VALUES (20261001, '2026-10-01', 2026, '2026-10')")
    con.executemany('INSERT INTO fact_sales VALUES (?,?,?,?,?,?,?)', [
        # order_id, line_no, date_key, product_key, store_key, quantity, unit_price
        ('O1007', 1, 20261001, 1, 1, 3, 50),   # Tea 3 ชิ้น Chonburi (Bangsaen)
        ('O1007', 2, 20261001, 2, 1, 2, 80),   # Cookie 2 ชิ้น Chonburi
        ('O1008', 1, 20261001, 1, 2, 4, 50),   # Tea 4 ชิ้น Bangkok (Siam)
    ])
    con.commit()
except sqlite3.IntegrityError as e:
    con.rollback(); raise SystemExit(f'INSERT ล้มเหลว rollback: {e}')
print('FK check (ว่าง = ผ่าน):', con.execute('PRAGMA foreign_key_check').fetchall())
after = q(con, 'SELECT COUNT(*) n_rows, COUNT(DISTINCT order_id) n_orders, SUM(amount) revenue FROM sales')
q(con, '''SELECT 'fact' src, COUNT(*) n, SUM(quantity*unit_price) rev FROM fact_sales
          UNION ALL SELECT 'view', COUNT(*), SUM(amount) FROM sales''')
df = pd.read_sql_query('SELECT * FROM sales', con)
pv = pd.pivot_table(df, index='province', columns='month', values='amount',
                    aggfunc='sum', fill_value=0, margins=True, margins_name='Total')
print(pv)
assert pv.loc['Total', 'Total'] == df['amount'].sum() == 1390 + 150 + 160 + 200
pv.to_csv(OUT / 'pivot_with_october.csv', encoding='utf-8-sig')
print('\nยอดเพิ่ม = 3*50 + 2*80 + 4*50 = 510 บาท -> รวม', df['amount'].sum())
con.close()
