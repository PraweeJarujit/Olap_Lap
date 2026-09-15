from pathlib import Path
import sqlite3
import pandas as pd
ROOT=Path(__file__).resolve().parent
with sqlite3.connect((ROOT/'data'/'warehouse.db').as_uri()+'?mode=ro',uri=True) as con:
    df=pd.read_sql_query('SELECT * FROM sales',con)
print(df.head())

OUT = ROOT/'67160349_olap_lab'/'results'
OUT.mkdir(parents=True, exist_ok=True)

# P1: province x month, sum(amount), fill_value=0, margins=True
p1 = df.pivot_table(index='province', columns='month', values='amount',
                     aggfunc='sum', fill_value=0, margins=True, margins_name='Total')
print('\nP1 province x month:\n', p1)
p1.to_csv(OUT/'pivot_province_month.csv')

# Error experiment: drop aggfunc -> pandas defaults to mean, not sum
p1_mean = df.pivot_table(index='province', columns='month', values='amount',
                          fill_value=0, margins=True, margins_name='Total')
print('\nP1 without aggfunc (defaults to mean):\n', p1_mean)
p1_mean.to_csv(OUT/'pivot_province_month_mean_bug.csv')

# P2: filter September, then category x province
sep = df[df['month'] == '2026-09']
p2 = sep.pivot_table(index='category', columns='province', values='amount',
                      aggfunc='sum', fill_value=0)
print('\nP2 September category x province:\n', p2)
p2.to_csv(OUT/'pivot_september.csv')

# P3: assert Grand Total of P1 equals df['amount'].sum() — Total x Total cell only
assert p1.loc['Total', 'Total'] == df['amount'].sum(), 'Grand total mismatch'
print('\nP3 assert passed: pivot grand total', p1.loc['Total', 'Total'],
      '== df amount sum', df['amount'].sum())

# P4: results already exported to CSV above (pivot_province_month.csv, pivot_september.csv)

# No Excel available in this environment: per the lab's fallback, filter category == "Drink"
# in pandas and redo the same province x month Sum pivot (Rows=province, Columns=month, Values=amount, Sum).
drink = df[df['category'] == 'Drink']
p_drink = drink.pivot_table(index='province', columns='month', values='amount',
                             aggfunc='sum', fill_value=0, margins=True, margins_name='Total')
print('\nDrink-only pivot (province x month, sum):\n', p_drink)
p_drink.to_csv(OUT/'pivot_drink_only.csv')
print('\nDrink-only grand total:', p_drink.loc['Total', 'Total'], 'baht')
print('Rows=province, Columns=month, Values=amount (Sum)')
