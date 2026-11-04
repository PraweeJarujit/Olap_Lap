"""
รันเฉลย Coast Café ทั้งหมดในครั้งเดียว แล้วเก็บผลทุกข้อ
    pip install duckdb pandas openpyxl
    python run_all.py                      # ใช้ coast_cafe_all.sql
    python run_all.py my_answers.sql       # หรือไฟล์ SQL อื่นที่ใช้ "-- @@ ชื่อ | คำอธิบาย" แบ่งข้อ

ผลลัพธ์:
    output/<ข้อ>.csv     ผลของคำสั่ง SELECT สุดท้ายในแต่ละข้อ
    output/results.xlsx   รวมทุกข้อ (1 ชีตต่อ 1 ข้อ)
    output/RESULTS.md     SQL + ตารางผลลัพธ์ของทุกข้อ (เปิดอ่าน/แปะรายงานได้ทันที)
    output/pivot_*.csv    Pivot ด้วย pandas (แบบสไลด์ 29/37) + assert ตรวจยอด
    coast_cafe.duckdb     ฐานข้อมูลที่มีตาราง/วิวทั้งหมด เปิดต่อด้วย duckdb CLI ได้
"""
import re
import sys
from pathlib import Path

try:
    import duckdb
    import pandas as pd
except ImportError:
    raise SystemExit("ติดตั้งก่อน:  python -m pip install duckdb pandas openpyxl")

HERE = Path(__file__).resolve().parent
SQL_FILE = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "coast_cafe_all.sql"
OUT = HERE / "output"
OUT.mkdir(exist_ok=True)
DB = HERE / "coast_cafe.duckdb"

pd.set_option("display.width", 200)
pd.set_option("display.max_columns", 30)
pd.set_option("display.max_rows", 40)


def split_blocks(text):
    """แบ่งไฟล์ตาม '-- @@ name | desc' -> [(name, desc, sql)]"""
    parts = re.split(r"^--\s*@@\s*(.+)$", text, flags=re.M)
    blocks = []
    for i in range(1, len(parts), 2):
        head, body = parts[i], parts[i + 1]
        name, _, desc = head.partition("|")
        blocks.append((name.strip(), desc.strip(), body.strip()))
    return blocks


def split_statements(con, sql):
    try:
        return [s.query for s in con.extract_statements(sql)]
    except Exception:
        return [s for s in (x.strip() for x in sql.split(";")) if s and not all(
            ln.strip().startswith("--") or not ln.strip() for ln in s.splitlines())]


def df_to_md(df, max_rows=60):
    if df is None or df.empty:
        return "_(ไม่มีแถวผลลัพธ์)_\n"
    d = df.head(max_rows)
    lines = ["| " + " | ".join(map(str, d.columns)) + " |", "|" + "---|" * len(d.columns)]
    lines += ["| " + " | ".join("" if pd.isna(x) else str(x) for x in r) + " |" for r in d.values.tolist()]
    if len(df) > max_rows:
        lines.append(f"\n_... แสดง {max_rows} จาก {len(df)} แถว (ดูครบใน CSV)_")
    return "\n".join(lines) + "\n"


def main():
    import os
    os.chdir(HERE)                      # ให้ read_csv_auto('orders.csv') หาไฟล์เจอ
    if DB.exists():
        DB.unlink()
    con = duckdb.connect(str(DB))
    blocks = split_blocks(SQL_FILE.read_text(encoding="utf-8"))
    md = [f"# ผลลัพธ์ทั้งหมดจาก {SQL_FILE.name}\n"]
    sheets = {}
    errors = 0
    for name, desc, sql in blocks:
        print("=" * 90)
        print(f"[{name}] {desc}")
        last_df = None
        try:
            for stmt in split_statements(con, sql):
                rel = con.execute(stmt)
                if rel is not None and rel.description:   # มีผลลัพธ์ (SELECT/PIVOT/EXPLAIN)
                    last_df = rel.fetchdf()
        except Exception as e:
            errors += 1
            print("  !! ERROR:", e)
            md.append(f"## {name} — {desc}\n\n```sql\n{sql}\n```\n\n**ERROR:** `{e}`\n")
            continue
        if last_df is not None:
            print(last_df.to_string(max_rows=25))
            last_df.to_csv(OUT / f"{name}.csv", index=False, encoding="utf-8-sig")
            sheets[name[:31]] = last_df
        md.append(f"## {name} — {desc}\n\n```sql\n{sql}\n```\n\n{df_to_md(last_df)}\n")

    # ---------- Pivot ด้วย pandas (แนวสไลด์ 29, 31-32, 37) ----------
    print("=" * 90)
    print("[PANDAS PIVOT]")
    df = con.execute("SELECT * FROM v_sales").fetchdf()
    p1 = pd.pivot_table(df, index="province", columns="month", values="net_sales",
                        aggfunc="sum", fill_value=0, margins=True, margins_name="Total").round(2)
    p2 = pd.pivot_table(df[df["month"] == "2026-09"], index="category", columns="province",
                        values="net_sales", aggfunc="sum", fill_value=0).round(2)
    p_wrong = pd.pivot_table(df, index="province", columns="month", values="net_sales").round(2)  # ลืม aggfunc → mean
    drinks = pd.pivot_table(df[df["category"] == "เครื่องดื่ม"], index="province", columns="month",
                            values="net_sales", aggfunc="sum", fill_value=0, margins=True,
                            margins_name="Total").round(2)
    # assert: เลือกเฉพาะเซลล์ Total×Total ห้าม sum ทั้งตาราง (จะนับซ้ำ)
    assert abs(p1.loc["Total", "Total"] - df["net_sales"].sum()) < 0.01, "Grand total ไม่ตรง!"
    assert abs(p2.values.sum() - df.loc[df["month"] == "2026-09", "net_sales"].sum()) < 0.01
    for nm, t in [("pivot_province_month", p1), ("pivot_september_category_province", p2),
                  ("pivot_WRONG_mean", p_wrong), ("pivot_drink_only", drinks)]:
        t.to_csv(OUT / f"{nm}.csv", encoding="utf-8-sig")
        sheets[nm[:31]] = t.reset_index()
        print(f"\n{nm}\n{t}")
        md.append(f"## {nm} (pandas)\n\n{df_to_md(t.reset_index())}\n")
    print("\nassert ผ่าน: Grand total ของ Pivot = ยอดรวม fact =", round(df['net_sales'].sum(), 2))
    md.append(f"**assert ผ่าน:** Grand total = {round(df['net_sales'].sum(), 2)} บาท\n")

    # ---------- บันทึก ----------
    try:
        with pd.ExcelWriter(OUT / "results.xlsx") as xw:
            for sh, t in sheets.items():
                t.to_excel(xw, sheet_name=sh, index=False)
    except ImportError:
        print("(ไม่มี openpyxl จึงข้าม results.xlsx — pip install openpyxl)")
    (OUT / "RESULTS.md").write_text("\n".join(md), encoding="utf-8")
    con.close()
    print("=" * 90)
    print(f"เสร็จ {len(blocks)} ข้อ, error {errors} ข้อ → ดูผลที่ {OUT}")


if __name__ == "__main__":
    main()
