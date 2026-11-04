-- ทางเลือกเสริม (ข้อ 10): Refresh อัตโนมัติใน MySQL
-- รันหลังไฟล์ week10_summary_table_mysql.sql (phpMyAdmin/mysql CLI รองรับคำสั่ง DELIMITER)
USE dw_lab10;
DELIMITER $$

-- (1) Stored Procedure: เรียก CALL refresh_summary(); ได้ทุกเมื่อ
DROP PROCEDURE IF EXISTS refresh_summary $$
CREATE PROCEDURE refresh_summary()
BEGIN
    START TRANSACTION;
    DELETE FROM summary_sales_month_product;
    INSERT INTO summary_sales_month_product (sales_month, product_id, revenue, quantity, order_count, last_refreshed)
    SELECT DATE_FORMAT(order_date,'%Y-%m'), product_id, SUM(amount), SUM(qty), COUNT(*), NOW()
    FROM fact_sales GROUP BY DATE_FORMAT(order_date,'%Y-%m'), product_id;
    COMMIT;
END $$

-- (2) Trigger: ทุก INSERT ใน fact_sales อัปเดต summary ทันที (upsert แบบบวกเพิ่ม)
DROP TRIGGER IF EXISTS trg_fact_sales_ai $$
CREATE TRIGGER trg_fact_sales_ai AFTER INSERT ON fact_sales
FOR EACH ROW
BEGIN
    INSERT INTO summary_sales_month_product (sales_month, product_id, revenue, quantity, order_count, last_refreshed)
    VALUES (DATE_FORMAT(NEW.order_date,'%Y-%m'), NEW.product_id, NEW.amount, NEW.qty, 1, NOW())
    ON DUPLICATE KEY UPDATE revenue     = revenue + NEW.amount,
                            quantity    = quantity + NEW.qty,
                            order_count = order_count + 1,
                            last_refreshed = NOW();
END $$

-- (3) Event รายคืนตี 2 (ต้องเปิด SET GLOBAL event_scheduler = ON; ต้องมีสิทธิ์ admin)
DROP EVENT IF EXISTS ev_refresh_summary_nightly $$
CREATE EVENT ev_refresh_summary_nightly
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR)
DO CALL refresh_summary() $$
DELIMITER ;

-- ทดสอบ: CALL refresh_summary();  SELECT SUM(revenue) FROM summary_sales_month_product;
CALL refresh_summary();
SELECT SUM(revenue) AS summary_total FROM summary_sales_month_product;

-- ข้อดี/ข้อเสีย:  Trigger = สดตลอดแต่ INSERT ช้าลง และไม่รองรับ UPDATE/DELETE ถ้าไม่เขียนเพิ่ม
--                 Event/Batch = ไม่กระทบ OLTP แต่มีช่วงข้อมูลค้าง (latency) -> ควรแสดง last_refreshed บน Dashboard
