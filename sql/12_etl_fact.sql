/* ============================================================================
   12_etl_fact.sql (מעודכן)
   מטרה: טעינת 3 טבלאות העובדה - כל אחת בגרעין הנכון שלה, כולל FK ל-Dim_Order.
   ============================================================================ */

USE olist_DWH;
GO

TRUNCATE TABLE dbo.Fact_Order_Items;
TRUNCATE TABLE dbo.Fact_Payments;
TRUNCATE TABLE dbo.Fact_Reviews;
GO

-------------------------------------------------------------------
-- Fact_Order_Items : grain = order_id + order_item_id
-------------------------------------------------------------------
INSERT INTO dbo.Fact_Order_Items (
    Order_ID, Order_Item_ID, Order_Key, Customer_Key, Seller_Key, Product_Key, Purchase_Date_Key, Delivered_Date_Key,
    Purchase_Timestamp, Delivered_Carrier_Date, Delivered_Customer_Date, Estimated_Delivery_Date,
    Price, Freight_Value, Delivery_Delay_Days, Actual_Delivery_Days
)
SELECT
    oi.order_id, oi.order_item_id, dord.Order_Key, dc.Customer_Key, ds.Seller_Key, dp.Product_Key,
    CAST(CONVERT(VARCHAR(8), o.order_purchase_timestamp, 112) AS INT),
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN CAST(CONVERT(VARCHAR(8), o.order_delivered_customer_date, 112) AS INT) END,
    o.order_purchase_timestamp, o.order_delivered_carrier_date, o.order_delivered_customer_date, o.order_estimated_delivery_date,
    oi.price, oi.freight_value,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL THEN DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) END,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL THEN DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) END
FROM olist_STG.dbo.stg_order_items oi
JOIN olist_STG.dbo.stg_orders o ON oi.order_id = o.order_id
LEFT JOIN olist_STG.dbo.stg_customers stgc ON o.customer_id = stgc.customer_id
LEFT JOIN dbo.Dim_Customer dc ON stgc.customer_unique_id = dc.Customer_Unique_ID
LEFT JOIN dbo.Dim_Order dord ON o.order_id = dord.Order_ID
LEFT JOIN dbo.Dim_Seller ds ON oi.seller_id = ds.Seller_ID
LEFT JOIN dbo.Dim_Product dp ON oi.product_id = dp.Product_ID;
GO

-------------------------------------------------------------------
-- Fact_Payments : grain = order_id + payment_sequential
-------------------------------------------------------------------
INSERT INTO dbo.Fact_Payments (Order_ID, Payment_Sequential, Order_Key, Customer_Key, Purchase_Date_Key, Payment_Type, Payment_Installments, Payment_Value)
SELECT
    pay.order_id, pay.payment_sequential, dord.Order_Key, dc.Customer_Key,
    CAST(CONVERT(VARCHAR(8), o.order_purchase_timestamp, 112) AS INT),
    pay.payment_type, pay.payment_installments, pay.payment_value
FROM olist_STG.dbo.stg_payments pay
JOIN olist_STG.dbo.stg_orders o ON pay.order_id = o.order_id
LEFT JOIN olist_STG.dbo.stg_customers stgc ON o.customer_id = stgc.customer_id
LEFT JOIN dbo.Dim_Customer dc ON stgc.customer_unique_id = dc.Customer_Unique_ID
LEFT JOIN dbo.Dim_Order dord ON o.order_id = dord.Order_ID;
GO

-------------------------------------------------------------------
-- Fact_Reviews : grain = review_id
-------------------------------------------------------------------
INSERT INTO dbo.Fact_Reviews (Review_ID, Order_ID, Order_Key, Customer_Key, Purchase_Date_Key, Review_Score)
SELECT
    r.review_id, r.order_id, dord.Order_Key, dc.Customer_Key,
    CAST(CONVERT(VARCHAR(8), o.order_purchase_timestamp, 112) AS INT),
    r.review_score
FROM olist_STG.dbo.stg_reviews r
JOIN olist_STG.dbo.stg_orders o ON r.order_id = o.order_id
LEFT JOIN olist_STG.dbo.stg_customers stgc ON o.customer_id = stgc.customer_id
LEFT JOIN dbo.Dim_Customer dc ON stgc.customer_unique_id = dc.Customer_Unique_ID
LEFT JOIN dbo.Dim_Order dord ON o.order_id = dord.Order_ID;
GO
