/* ============================================================================
   03_verify_source_load.sql
   מטרה: ולידציה בסיסית שהטעינה מה-CSV הצליחה - השוואת ספירות שורות מול
   הצפוי (מספרי הייחוס הידועים של דאטהסט Olist ב-Kaggle), ובדיקת NULL
   במפתחות קריטיים שאסור שיהיו ריקים.
   ============================================================================ */

USE olist_db;
GO

SELECT 'olist_customers_dataset' AS TableName, COUNT(*) AS ActualRows, 99441 AS ExpectedRows FROM dbo.olist_customers_dataset
UNION ALL SELECT 'olist_geolocation_dataset', COUNT(*), 1000163 FROM dbo.olist_geolocation_dataset
UNION ALL SELECT 'olist_orders_dataset', COUNT(*), 99441 FROM dbo.olist_orders_dataset
UNION ALL SELECT 'olist_order_items_dataset', COUNT(*), 112650 FROM dbo.olist_order_items_dataset
UNION ALL SELECT 'olist_order_payments_dataset', COUNT(*), 103886 FROM dbo.olist_order_payments_dataset
UNION ALL SELECT 'olist_order_reviews_dataset', COUNT(*), 99224 FROM dbo.olist_order_reviews_dataset
UNION ALL SELECT 'olist_products_dataset', COUNT(*), 32951 FROM dbo.olist_products_dataset
UNION ALL SELECT 'olist_sellers_dataset', COUNT(*), 3095 FROM dbo.olist_sellers_dataset
UNION ALL SELECT 'product_category_name_translation', COUNT(*), 71 FROM dbo.product_category_name_translation;
GO

-- בדיקת NULL במפתחות קריטיים (אמורות להחזיר 0 בכל שורה)
SELECT 'customers.customer_id NULL'   AS Check_, COUNT(*) AS Cnt FROM dbo.olist_customers_dataset     WHERE customer_id IS NULL
UNION ALL SELECT 'orders.order_id NULL',          COUNT(*)        FROM dbo.olist_orders_dataset        WHERE order_id IS NULL
UNION ALL SELECT 'order_items.order_id NULL',     COUNT(*)        FROM dbo.olist_order_items_dataset    WHERE order_id IS NULL
UNION ALL SELECT 'reviews.review_id NULL',        COUNT(*)        FROM dbo.olist_order_reviews_dataset  WHERE review_id IS NULL;
GO
