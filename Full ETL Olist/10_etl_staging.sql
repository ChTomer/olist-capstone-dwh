/* ============================================================================
   10_etl_staging.sql (מעודכן)
   מטרה: טעינת olist_STG מה-מקור, בשמות/עמודות האמיתיים אצלך - Truncate & Load.
   ============================================================================ */

USE olist_STG;
GO

TRUNCATE TABLE dbo.stg_reviews;
TRUNCATE TABLE dbo.stg_payments;
TRUNCATE TABLE dbo.stg_order_items;
TRUNCATE TABLE dbo.stg_orders;
TRUNCATE TABLE dbo.stg_products;
TRUNCATE TABLE dbo.stg_sellers;
TRUNCATE TABLE dbo.stg_geolocation;
TRUNCATE TABLE dbo.stg_customers;
GO

INSERT INTO dbo.stg_customers (customer_id, customer_unique_id, customer_city, customer_state, customer_zip_code_prefix)
SELECT customer_id, customer_unique_id,
       UPPER(TRIM(customer_city)), UPPER(TRIM(customer_state)),
       RIGHT('00000' + CAST(customer_zip_code_prefix AS VARCHAR(5)), 5)
FROM olist_db.dbo.olist_customers_dataset;
GO

INSERT INTO dbo.stg_geolocation (zip_code_prefix, latitude, longitude)
SELECT RIGHT('00000' + CAST(geolocation_zip_code_prefix AS VARCHAR(5)), 5),
       geolocation_lat, geolocation_lng
FROM olist_db.dbo.olist_geolocation_dataset;
GO

INSERT INTO dbo.stg_sellers (seller_id, seller_city, seller_state, seller_zip_code_prefix)
SELECT seller_id, UPPER(TRIM(seller_city)), UPPER(TRIM(seller_state)),
       RIGHT('00000' + CAST(seller_zip_code_prefix AS VARCHAR(5)), 5)
FROM olist_db.dbo.olist_sellers_dataset;
GO

-- תרגום קטגוריה כבר כאן (JOIN 1:1, לא משנה grain) - נשמר גם המקור וגם התרגום
-- הערה: טבלת התרגום אצלך משתמשת בשמות prod_cat_name_por / prod_cat_name_Eng
INSERT INTO dbo.stg_products (product_id, product_category_name, product_category_name_eng, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT p.product_id, p.product_category_name,
       COALESCE(t.prod_cat_name_Eng, p.product_category_name, 'Unknown'),
       p.product_weight_g, p.product_length_cm, p.product_height_cm, p.product_width_cm
FROM olist_db.dbo.olist_products_dataset p
LEFT JOIN olist_db.dbo.product_category_name_translation t
    ON p.product_category_name = t.prod_cat_name_por;
GO

INSERT INTO dbo.stg_orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date)
SELECT order_id, customer_id, LOWER(TRIM(order_status)), order_purchase_timestamp, order_approved_at,
       order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date
FROM olist_db.dbo.olist_orders_dataset;
GO

INSERT INTO dbo.stg_order_items (order_id, order_item_id, product_id, seller_id, price, freight_value)
SELECT order_id, order_item_id, product_id, seller_id, price, freight_value
FROM olist_db.dbo.olist_order_items_dataset;
GO

INSERT INTO dbo.stg_payments (order_id, payment_sequential, payment_type, payment_installments, payment_value)
SELECT order_id, payment_sequential, LOWER(TRIM(payment_type)), payment_installments, payment_value
FROM olist_db.dbo.olist_order_payments_dataset;
GO

INSERT INTO dbo.stg_reviews (review_id, order_id, review_score)
SELECT review_id, order_id, review_score
FROM olist_db.dbo.olist_order_reviews_dataset;
GO
