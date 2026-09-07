/* ============================================================================
   04_constraints_and_indexes.sql
   מטרה: הוספת PK טבעי היכן שיש, FK תפעוליים ואינדקסים תומכי-JOIN.
   olist_geolocation_dataset ללא PK בכוונה - יש בו כפילויות רבות באותו
   zip_code_prefix (זו בדיוק הסיבה שב-DWH צריך AVG לפי zip).
   ============================================================================ */

USE olist_db;
GO

ALTER TABLE dbo.olist_customers_dataset      ADD CONSTRAINT PK_customers      PRIMARY KEY (customer_id);
ALTER TABLE dbo.olist_orders_dataset         ADD CONSTRAINT PK_orders         PRIMARY KEY (order_id);
ALTER TABLE dbo.olist_order_items_dataset    ADD CONSTRAINT PK_order_items    PRIMARY KEY (order_id, order_item_id);
ALTER TABLE dbo.olist_order_payments_dataset ADD CONSTRAINT PK_order_payments PRIMARY KEY (order_id, payment_sequential);
ALTER TABLE dbo.olist_order_reviews_dataset  ADD CONSTRAINT PK_order_reviews  PRIMARY KEY (review_id);
ALTER TABLE dbo.olist_products_dataset       ADD CONSTRAINT PK_products       PRIMARY KEY (product_id);
ALTER TABLE dbo.olist_sellers_dataset        ADD CONSTRAINT PK_sellers        PRIMARY KEY (seller_id);
GO

-- FK תפעוליים - מדגימים את הקשרים האמיתיים בין ישויות המקור
ALTER TABLE dbo.olist_orders_dataset      ADD CONSTRAINT FK_orders_customers FOREIGN KEY (customer_id) REFERENCES dbo.olist_customers_dataset(customer_id);
ALTER TABLE dbo.olist_order_items_dataset ADD CONSTRAINT FK_items_orders    FOREIGN KEY (order_id)     REFERENCES dbo.olist_orders_dataset(order_id);
ALTER TABLE dbo.olist_order_items_dataset ADD CONSTRAINT FK_items_products  FOREIGN KEY (product_id)   REFERENCES dbo.olist_products_dataset(product_id);
ALTER TABLE dbo.olist_order_items_dataset ADD CONSTRAINT FK_items_sellers   FOREIGN KEY (seller_id)    REFERENCES dbo.olist_sellers_dataset(seller_id);
ALTER TABLE dbo.olist_order_payments_dataset ADD CONSTRAINT FK_payments_orders FOREIGN KEY (order_id) REFERENCES dbo.olist_orders_dataset(order_id);
ALTER TABLE dbo.olist_order_reviews_dataset  ADD CONSTRAINT FK_reviews_orders  FOREIGN KEY (order_id) REFERENCES dbo.olist_orders_dataset(order_id);
GO

-- אינדקסים תומכי-JOIN (geolocation מצטרף לפי zip prefix בהיקף גדול)
CREATE NONCLUSTERED INDEX IX_geo_zip           ON dbo.olist_geolocation_dataset(geolocation_zip_code_prefix);
CREATE NONCLUSTERED INDEX IX_customers_zip     ON dbo.olist_customers_dataset(customer_zip_code_prefix);
CREATE NONCLUSTERED INDEX IX_sellers_zip       ON dbo.olist_sellers_dataset(seller_zip_code_prefix);
CREATE NONCLUSTERED INDEX IX_customers_uniq_id ON dbo.olist_customers_dataset(customer_unique_id);
GO
