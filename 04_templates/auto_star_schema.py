"""
auto_star_schema.py — เครื่องมือสร้าง Star Schema + OLAP report อัตโนมัติจากข้อมูลชุดใหม่ (ใช้ตอนเจอโจทย์ที่ไม่เคยเห็น)
ใช้ DuckDB:  python -m pip install duckdb pandas openpyxl

ตัวอย่าง 1: ไฟล์ CSV แบน (flat) ไฟล์เดียว เช่น week09 warehouse.csv
  python auto_star_schema.py --source ../02_week09_olap_sqlite/data/warehouse.csv \
      --date full_date --order-id order_id \
      --dim product:product_name,category --dim store:store_name,province,region \
      --measure quantity --measure amount

ตัวอย่าง 2: หลายตาราง (normalized) ให้ JOIN ด้วย --source-sql เช่น Coast Café
  python auto_star_schema.py --source-sql "SELECT o.*, c.customer_name, c.province, c.segment,
        p.product_name, p.category, p.unit_cost FROM read_csv_auto('orders.csv') o
        JOIN read_csv_auto('customers.csv') c USING (customer_id)
        JOIN read_csv_auto('products.csv') p USING (product_id)" \
      --workdir ../01_coast_cafe_duckdb \
      --filter "status = 'Completed'" \
      --derive "net_sales = ROUND(quantity*unit_price*(1-discount_pct/100.0),2)" \
      --date order_date --order-id order_id \
      --dim customer:customer_id,customer_name,province,segment \
      --dim product:product_id,product_name,category --dim channel:channel \
      --measure quantity --measure net_sales

ผลลัพธ์ในโฟลเดอร์ --out (ค่าเริ่มต้น star_output/):
  star.duckdb             ฐานข้อมูลที่มี dim_* และ fact_sales + view v_sales
  star_schema_ddl.sql     SQL ที่สร้าง Star Schema ทั้งหมด (คัดลอกไปใช้/ส่งงานได้)
  star_schema.mmd/.html   แผนภาพ Star Schema (Mermaid) เปิด .html ใน browser ได้ทันที
  REPORT.md + *.csv       Validation, Roll-up, Drill-down, Slice, Pivot, Top-N, AOV ต่อทุกมิติ
"""
import argparse
import os
from pathlib import Path

import duckdb
import pandas as pd


def parse():
    ap = argparse.ArgumentParser(description="Build a star schema + OLAP report from flat data")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--source", help="CSV/Parquet file path")
    src.add_argument("--source-sql", help="SELECT query that returns the flat dataset")
    ap.add_argument("--workdir", default=".", help="folder to run in (for relative paths inside --source-sql)")
    ap.add_argument("--filter", help="WHERE condition applied to source, e.g. status = 'Completed'")
    ap.add_argument("--derive", action="append", default=[], help="new column: name = expression")
    ap.add_argument("--date", required=True, help="date column")
    ap.add_argument("--order-id", help="order/transaction id column (degenerate dimension, for AOV)")
    ap.add_argument("--dim", action="append", default=[], help="name:natural_key,attr1,attr2 (first col = natural key)")
    ap.add_argument("--measure", action="append", default=[], help="numeric additive measure column")
    ap.add_argument("--main-measure", help="measure used for revenue in reports (default = last --measure)")
    ap.add_argument("--out", default="star_output")
    return ap.parse_args()


def md_table(df, n=40):
    if df is None or df.empty:
        return "_(ไม่มีแถว)_\n"
    d = df.head(n)
    s = ["| " + " | ".join(map(str, d.columns)) + " |", "|" + "---|" * len(d.columns)]
    s += ["| " + " | ".join("" if pd.isna(x) else str(x) for x in r) + " |" for r in d.values.tolist()]
    return "\n".join(s) + ("\n_…ดูครบใน CSV_\n" if len(df) > n else "\n")


def main():
    a = parse()
    out = Path(a.out).resolve()
    os.chdir(Path(a.workdir).resolve())
    out.mkdir(parents=True, exist_ok=True)
    db = out / "star.duckdb"
    if db.exists():
        db.unlink()
    con = duckdb.connect(str(db))
    ddl, report = [], ["# Star Schema & OLAP Report\n"]
    M = a.main_measure or a.measure[-1]

    def run(sql, keep=True):
        if keep:
            ddl.append(sql.strip() + ";\n")
        return con.execute(sql)

    def show(title, sql, fname):
        df = con.execute(sql).fetchdf()
        df.to_csv(out / f"{fname}.csv", index=False, encoding="utf-8-sig")
        report.append(f"## {title}\n```sql\n{sql.strip()}\n```\n{md_table(df)}\n")
        print(f"\n=== {title}\n{df.head(15).to_string()}")
        return df

    # ---------- 1) staging ----------
    base = f"SELECT * FROM '{a.source}'" if a.source else a.source_sql
    derived = ", ".join(d.split("=", 1)[1].strip() + " AS " + d.split("=", 1)[0].strip() for d in a.derive)
    stg = f"SELECT *{', ' + derived if derived else ''} FROM ({base}) src"
    if a.filter:
        stg += f" WHERE {a.filter}"
    run(f"CREATE OR REPLACE TABLE stg_sales AS {stg}")

    # ---------- 2) dim_date ----------
    run(f"""CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_key, CAST(d AS DATE) AS full_date,
       year(d) AS year, quarter(d) AS quarter, month(d) AS month_no, strftime(d, '%Y-%m') AS month,
       dayofweek(d) AS day_of_week, strftime(d, '%a') AS day_name,
       CASE WHEN dayofweek(d) IN (0,6) THEN 'Weekend' ELSE 'Weekday' END AS day_type
FROM generate_series((SELECT MIN(CAST({a.date} AS DATE)) FROM stg_sales),
                     (SELECT MAX(CAST({a.date} AS DATE)) FROM stg_sales), INTERVAL 1 DAY) t(d)""")

    # ---------- 3) other dims (surrogate key = ROW_NUMBER) ----------
    dims = []
    for spec in a.dim:
        name, cols = spec.split(":")
        cols = [c.strip() for c in cols.split(",")]
        nk = cols[0]
        run(f"""CREATE OR REPLACE TABLE dim_{name} AS
SELECT ROW_NUMBER() OVER (ORDER BY {nk}) AS {name}_key, {', '.join(cols)}
FROM (SELECT DISTINCT ON ({nk}) {', '.join(cols)} FROM stg_sales ORDER BY {nk})""")
        dims.append((name, nk, cols))

    # ---------- 4) fact ----------
    joins = "\n".join(f"JOIN dim_{n} d_{n} ON s.{nk} IS NOT DISTINCT FROM d_{n}.{nk}" for n, nk, _ in dims)
    fks = ", ".join(f"d_{n}.{n}_key" for n, _, _ in dims)
    oid = f"s.{a.order_id}, " if a.order_id else ""
    run(f"""CREATE OR REPLACE TABLE fact_sales AS
SELECT {oid}CAST(strftime(CAST(s.{a.date} AS DATE), '%Y%m%d') AS INTEGER) AS date_key{', ' + fks if fks else ''},
       {', '.join('s.' + m for m in a.measure)}
FROM stg_sales s
{joins}""")

    # ---------- 5) view ที่ JOIN กลับ ----------
    vj = "\n".join(f"JOIN dim_{n} USING ({n}_key)" for n, _, _ in dims)
    attrs = ", ".join(f"dim_{n}.{c}" for n, nk, cols in dims for c in cols)
    run(f"""CREATE OR REPLACE VIEW v_sales AS
SELECT {('f.' + a.order_id + ', ') if a.order_id else ''}d.full_date, d.year, d.quarter, d.month, d.day_name, d.day_type,
       {attrs}, {', '.join('f.' + m for m in a.measure)}
FROM fact_sales f JOIN dim_date d USING (date_key)
{vj}""")
    (out / "star_schema_ddl.sql").write_text("\n".join(ddl), encoding="utf-8")

    # ---------- 6) Mermaid diagram ----------
    def cols_of(t):
        return con.execute(f"DESCRIBE {t}").fetchdf()[["column_name", "column_type"]].values.tolist()
    mm = ["erDiagram"]
    for t in ["dim_date"] + [f"dim_{n}" for n, _, _ in dims] + ["fact_sales"]:
        mm.append(f"    {t} {{")
        for c, ty in cols_of(t):
            ty = ty.split("(")[0].replace(" ", "_")
            tag = " PK" if (c.endswith("_key") and t.startswith("dim")) else (" FK" if c.endswith("_key") else "")
            mm.append(f"        {ty} {c}{tag}")
        mm.append("    }")
    mm.append('    dim_date ||--o{ fact_sales : "date_key"')
    for n, _, _ in dims:
        mm.append(f'    dim_{n} ||--o{{ fact_sales : "{n}_key"')
    mmd = "\n".join(mm)
    (out / "star_schema.mmd").write_text(mmd, encoding="utf-8")
    (out / "star_schema.html").write_text(
        "<!doctype html><meta charset='utf-8'><title>Star Schema</title>"
        "<script src='https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js'></script>"
        f"<pre class='mermaid'>{mmd}</pre><script>mermaid.initialize({{startOnLoad:true}})</script>",
        encoding="utf-8")
    report.append(f"## Star Schema\n```mermaid\n{mmd}\n```\n")

    # ---------- 7) Validation ----------
    show("Validation: staging vs fact vs view (ต้องเท่ากัน)", f"""
SELECT 'stg_sales' AS src, COUNT(*) AS n_rows, ROUND(SUM({M}),2) AS total FROM stg_sales
UNION ALL SELECT 'fact_sales', COUNT(*), ROUND(SUM({M}),2) FROM fact_sales
UNION ALL SELECT 'v_sales', COUNT(*), ROUND(SUM({M}),2) FROM v_sales""", "00_validation")
    show("Row count ของแต่ละตาราง", " UNION ALL ".join(
        f"SELECT '{t}' AS tbl, COUNT(*) AS n FROM {t}" for t in
        ["dim_date"] + [f"dim_{n}" for n, _, _ in dims] + ["fact_sales"]), "00_row_counts")

    # ---------- 8) KPI ----------
    kpi = f"COUNT(*) AS line_count, {'COUNT(DISTINCT ' + a.order_id + ') AS order_count, ' if a.order_id else ''}" + \
          ", ".join(f"ROUND(SUM({m}),2) AS sum_{m}" for m in a.measure)
    if a.order_id:
        kpi += f", ROUND(SUM({M})/COUNT(DISTINCT {a.order_id}),2) AS aov, ROUND(AVG({M}),2) AS avg_line"
    show("KPI ภาพรวม", f"SELECT {kpi} FROM v_sales", "01_kpi")

    # ---------- 9) OLAP per dimension ----------
    show("Roll-up: รายเดือน", f"SELECT month, ROUND(SUM({M}),2) AS {M} FROM v_sales GROUP BY month ORDER BY month", "02_rollup_month")
    months = [r[0] for r in con.execute("SELECT DISTINCT month FROM v_sales ORDER BY 1").fetchall()]
    last_m = months[-1]
    i = 3
    for n, nk, cols in dims:
        for c in cols[1:] if len(cols) > 1 else cols:     # ใช้ attribute (ข้าม natural key ถ้ามี attribute อื่น)
            show(f"Drill-down: month × {c}", f"""SELECT month, {c}, ROUND(SUM({M}),2) AS {M}
FROM v_sales GROUP BY month, {c} ORDER BY month, {M} DESC""", f"{i:02}_drill_month_{c}"); i += 1
            show(f"Slice {last_m}: by {c}", f"""SELECT {c}, ROUND(SUM({M}),2) AS {M}
FROM v_sales WHERE month = '{last_m}' GROUP BY {c} ORDER BY {M} DESC""", f"{i:02}_slice_{c}"); i += 1
            show(f"Pivot: {c} × month", f"""SELECT * FROM (PIVOT (SELECT {c}, month, {M} FROM v_sales)
ON month USING SUM({M}) GROUP BY {c}) ORDER BY {c}""", f"{i:02}_pivot_{c}"); i += 1
        show(f"Top 5 {n} ({nk})", f"""SELECT {', '.join(cols)}, COUNT(*) AS n_lines, ROUND(SUM({M}),2) AS {M}
FROM v_sales GROUP BY {', '.join(cols)} ORDER BY {M} DESC LIMIT 5""", f"{i:02}_top5_{n}"); i += 1
    if len(dims) >= 2:
        c1, c2 = dims[0][2][-1], dims[1][2][-1]
        show(f"ROLLUP ({c1}, {c2}) subtotal + grand total", f"""SELECT {c1}, {c2}, ROUND(SUM({M}),2) AS {M},
GROUPING({c1}, {c2}) AS lvl FROM v_sales GROUP BY ROLLUP ({c1}, {c2})
ORDER BY {c1} NULLS LAST, lvl, {M} DESC""", f"{i:02}_rollup_op"); i += 1
        show(f"CUBE ({c1}, {c2})", f"""SELECT {c1}, {c2}, ROUND(SUM({M}),2) AS {M} FROM v_sales
GROUP BY CUBE ({c1}, {c2}) ORDER BY {c1} NULLS LAST, {c2} NULLS LAST""", f"{i:02}_cube"); i += 1
        show(f"Rank {c2} ภายในแต่ละ {c1}", f"""SELECT {c1}, {c2}, ROUND(SUM({M}),2) AS {M},
RANK() OVER (PARTITION BY {c1} ORDER BY SUM({M}) DESC) AS rnk FROM v_sales
GROUP BY {c1}, {c2} ORDER BY {c1}, rnk""", f"{i:02}_rank"); i += 1
    show("ยอดรายวัน + MA7", f"""WITH d AS (SELECT full_date, SUM({M}) s FROM v_sales GROUP BY 1)
SELECT full_date, ROUND(s,2) AS daily, ROUND(AVG(s) OVER (ORDER BY full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS ma7,
ROUND(SUM(s) OVER (ORDER BY full_date),2) AS running_total FROM d ORDER BY 1""", f"{i:02}_daily_ma7")

    (out / "REPORT.md").write_text("\n".join(report), encoding="utf-8")
    con.close()
    print(f"\nเสร็จ → {out}  (เปิด REPORT.md / star_schema.html / star_schema_ddl.sql)")


if __name__ == "__main__":
    main()
