"""ภารกิจ 4 Pivot ด้วย pandas (P1–P4 + ทดลอง mean + Drink filter)
รัน: python pivot_student.py   -> ไฟล์อยู่ใน submission/
"""
from pathlib import Path
import sqlite3
import pandas as pd

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'submission'
OUT.mkdir(exist_ok=True)
DB = ROOT / 'data' / ('extended.db' if __import__('sys').argv[1:2] == ['ext'] else 'warehouse.db')

with sqlite3.connect(DB.as_uri() + '?mode=ro', uri=True) as con:
    df = pd.read_sql_query('SELECT * FROM sales', con)
print(df.head())

# P1: province x month, sum(amount), fill_value=0, margins=True
p1 = pd.pivot_table(df, index='province', columns='month', values='amount',
                    aggfunc='sum', fill_value=0, margins=True, margins_name='Total')
print('\nP1 province x month\n', p1)

# P2: กรองกันยายนก่อน แล้ว category x province
sep = df[df['month'] == '2026-09']
p2 = pd.pivot_table(sep, index='category', columns='province', values='amount',
                    aggfunc='sum', fill_value=0)
print('\nP2 September category x province\n', p2)

# P3: assert เฉพาะเซลล์ Total x Total (ห้าม sum ทั้งตารางเพราะมีแถว/คอลัมน์ Total ซ้ำ)
assert p1.loc['Total', 'Total'] == df['amount'].sum(), 'Grand total mismatch'
assert p2.values.sum() == sep['amount'].sum(), 'September total mismatch'
print('\nassert ผ่าน: grand total =', df['amount'].sum(), '| September =', sep['amount'].sum())

# ทดลองข้อผิดพลาด: ไม่ใส่ aggfunc -> ค่าเริ่มต้นคือ mean
p_mean = pd.pivot_table(df, index='province', columns='month', values='amount')
print('\nWRONG (default mean)\n', p_mean)
print('Bangkok Sep (mean) =', p_mean.loc['Bangkok', '2026-09'],
      '<- (300+240)/2 = ค่าเฉลี่ยต่อรายการสินค้า ไม่ใช่ยอดรวม')

# Excel-equivalent: Filter category = Drink
drink = pd.pivot_table(df[df['category'] == 'Drink'], index='province', columns='month',
                       values='amount', aggfunc='sum', fill_value=0,
                       margins=True, margins_name='Total')
print('\nDrink only\n', drink, '\nDrink total =', drink.loc['Total', 'Total'])

# P4: export
p1.to_csv(OUT / 'pivot_province_month.csv', encoding='utf-8-sig')
p2.to_csv(OUT / 'pivot_september.csv', encoding='utf-8-sig')
p_mean.to_csv(OUT / 'pivot_wrong_mean.csv', encoding='utf-8-sig')
drink.to_csv(OUT / 'pivot_drink.csv', encoding='utf-8-sig')
try:
    with pd.ExcelWriter(OUT / 'pivot.xlsx') as xw:
        p1.to_excel(xw, sheet_name='P1_province_month')
        p2.to_excel(xw, sheet_name='P2_september')
        drink.to_excel(xw, sheet_name='Drink')
        p_mean.to_excel(xw, sheet_name='WRONG_mean')
except ImportError:
    print('(ไม่มี openpyxl: ข้าม pivot.xlsx)')
print('\nบันทึกไฟล์ใน', OUT)

# คำถามชวนคิด: เพิ่มเดือนตุลาคม -> SQL ที่เขียน CASE ไว้แค่ aug/sep จะ "ไม่" มีคอลัมน์ใหม่ (ต้องเพิ่ม CASE เอง
# และ total จะยังรวม ต.ค. ทำให้ aug+sep != total) ส่วน pandas columns='month' สร้างคอลัมน์ 2026-10 ให้อัตโนมัติ
