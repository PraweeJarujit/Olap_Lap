-- เทียบจำนวนแถวและยอดก่อน JOIN (fact_sales) กับหลัง JOIN (view sales)
SELECT 'before_join_fact_sales' AS source, COUNT(*) AS n_rows, SUM(quantity * unit_price) AS revenue FROM fact_sales
UNION ALL
SELECT 'after_join_sales_view', COUNT(*), SUM(amount) FROM sales;
