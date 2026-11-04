CREATE OR REPLACE TABLE stg_sales AS SELECT *, ROUND(quantity*unit_price*(1-discount_pct/100.0),2) AS net_sales FROM (SELECT o.*, c.customer_name, c.province, c.segment, p.product_name, p.category FROM read_csv_auto('orders.csv') o JOIN read_csv_auto('customers.csv') c USING (customer_id) JOIN read_csv_auto('products.csv') p USING (product_id)) src WHERE status = 'Completed';

CREATE OR REPLACE TABLE dim_date AS
SELECT CAST(strftime(d, '%Y%m%d') AS INTEGER) AS date_key, CAST(d AS DATE) AS full_date,
       year(d) AS year, quarter(d) AS quarter, month(d) AS month_no, strftime(d, '%Y-%m') AS month,
       dayofweek(d) AS day_of_week, strftime(d, '%a') AS day_name,
       CASE WHEN dayofweek(d) IN (0,6) THEN 'Weekend' ELSE 'Weekday' END AS day_type
FROM generate_series((SELECT MIN(CAST(order_date AS DATE)) FROM stg_sales),
                     (SELECT MAX(CAST(order_date AS DATE)) FROM stg_sales), INTERVAL 1 DAY) t(d);

CREATE OR REPLACE TABLE dim_customer AS
SELECT ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key, customer_id, customer_name, province, segment
FROM (SELECT DISTINCT ON (customer_id) customer_id, customer_name, province, segment FROM stg_sales ORDER BY customer_id);

CREATE OR REPLACE TABLE dim_product AS
SELECT ROW_NUMBER() OVER (ORDER BY product_id) AS product_key, product_id, product_name, category
FROM (SELECT DISTINCT ON (product_id) product_id, product_name, category FROM stg_sales ORDER BY product_id);

CREATE OR REPLACE TABLE dim_channel AS
SELECT ROW_NUMBER() OVER (ORDER BY channel) AS channel_key, channel
FROM (SELECT DISTINCT ON (channel) channel FROM stg_sales ORDER BY channel);

CREATE OR REPLACE TABLE fact_sales AS
SELECT s.order_id, CAST(strftime(CAST(s.order_date AS DATE), '%Y%m%d') AS INTEGER) AS date_key, d_customer.customer_key, d_product.product_key, d_channel.channel_key,
       s.quantity, s.net_sales
FROM stg_sales s
JOIN dim_customer d_customer ON s.customer_id IS NOT DISTINCT FROM d_customer.customer_id
JOIN dim_product d_product ON s.product_id IS NOT DISTINCT FROM d_product.product_id
JOIN dim_channel d_channel ON s.channel IS NOT DISTINCT FROM d_channel.channel;

CREATE OR REPLACE VIEW v_sales AS
SELECT f.order_id, d.full_date, d.year, d.quarter, d.month, d.day_name, d.day_type,
       dim_customer.customer_id, dim_customer.customer_name, dim_customer.province, dim_customer.segment, dim_product.product_id, dim_product.product_name, dim_product.category, dim_channel.channel, f.quantity, f.net_sales
FROM fact_sales f JOIN dim_date d USING (date_key)
JOIN dim_customer USING (customer_key)
JOIN dim_product USING (product_key)
JOIN dim_channel USING (channel_key);
