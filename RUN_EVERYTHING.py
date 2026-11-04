"""รันทุกส่วนของชุดเตรียมสอบในครั้งเดียว:  python RUN_EVERYTHING.py"""
import subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PY = sys.executable
try:
    import duckdb, pandas  # noqa: F401
except ImportError:
    print('กำลังติดตั้ง duckdb pandas openpyxl ...')
    subprocess.run([PY, '-m', 'pip', 'install', 'duckdb', 'pandas', 'openpyxl'], check=False)

jobs = [
    ('Coast Café (DuckDB)', ROOT / '01_coast_cafe_duckdb' / 'run_all.py', []),
    ('Week 9 OLAP (SQLite + pandas)', ROOT / '02_week09_olap_sqlite' / 'run_all_week09.py', []),
]
for title, script, args in jobs:
    print('\n' + '#' * 80 + f'\n# {title}\n' + '#' * 80)
    r = subprocess.run([PY, str(script), *args], cwd=script.parent)
    print(f'-> {title}: {"สำเร็จ" if r.returncode == 0 else "มีข้อผิดพลาด"}')

print('\nWeek 10 (MySQL): เปิด phpMyAdmin > SQL > วาง 03_week10_summary_mysql/week10_summary_table_mysql.sql > Go')
print('ผลลัพธ์: 01_coast_cafe_duckdb/output/  และ  02_week09_olap_sqlite/submission/')
