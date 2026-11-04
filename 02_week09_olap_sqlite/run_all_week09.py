"""รันแลปสัปดาห์ 9 ทั้งหมดในครั้งเดียว
    python -m pip install pandas openpyxl
    python run_all_week09.py
ผล: submission/q01.csv ... q12.csv, pivot_*.csv, pivot.xlsx, challenge.db, RESULTS_week09.md
"""
from pathlib import Path
import sqlite3, subprocess, sys
import pandas as pd

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'submission'
OUT.mkdir(exist_ok=True)
PY = sys.executable

if not (ROOT / 'data' / 'warehouse.db').exists():
    subprocess.run([PY, str(ROOT / 'lab.py')], check=True)

md = ['# ผลแลปสัปดาห์ 9 (warehouse.db)\n']
with sqlite3.connect((ROOT / 'data' / 'warehouse.db').as_uri() + '?mode=ro', uri=True) as con:
    for i in range(1, 13):
        f = ROOT / f'q{i:02}.sql'
        sql = f.read_text(encoding='utf-8')
        d = pd.read_sql_query(sql, con)
        d.to_csv(OUT / f'q{i:02}.csv', index=False, encoding='utf-8-sig')
        print(f'===== {f.name}\n{d.to_string(index=False)}\n')
        md.append(f'## {f.name}\n```sql\n{sql}\n```\n```\n{d.to_string(index=False)}\n```\n')
    fk = con.execute('PRAGMA foreign_key_check').fetchall()
    print('PRAGMA foreign_key_check ->', fk or 'ไม่มีปัญหา (ว่าง)')
    md.append(f'## PRAGMA foreign_key_check\n`{fk or "ว่าง = ไม่มี FK หาย"}`\n')

for script in ['oltp_demo.py', 'oltp_demo.py', 'pivot_student.py', 'challenge.py']:
    print('#' * 70, '\n#', script)
    r = subprocess.run([PY, str(ROOT / script)], capture_output=True, text=True, encoding='utf-8')
    print(r.stdout, r.stderr)
    md.append(f'## {script}\n```\n{r.stdout}{r.stderr}\n```\n')
# คืน oltp.db เป็น PENDING ให้รันใหม่ได้
with sqlite3.connect(ROOT / 'data' / 'oltp.db') as c:
    c.execute("UPDATE orders SET status='PENDING' WHERE order_id='O1004'")

(OUT / 'RESULTS_week09.md').write_text('\n'.join(md), encoding='utf-8')
print('เสร็จ -> ดู', OUT)
