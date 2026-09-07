/* ============================================================================
   13_run_and_verify.sql (מעודכן)
   מטרה: בדיקות שפיות אחרי הרצת השרשרת המלאה.
   הרץ לפני כן, בסדר: 09 (usp_RefreshSourceMirror, אופציונלי) -> 10 -> 11 -> 12.
   ============================================================================ */

SELECT
    (SELECT COUNT(*) FROM olist_db.dbo.olist_order_items_dataset)    AS Source_Items,
    (SELECT COUNT(*) FROM olist_DWH.dbo.Fact_Order_Items)            AS Fact_Items,
    (SELECT COUNT(*) FROM olist_db.dbo.olist_order_payments_dataset) AS Source_Payments,
    (SELECT COUNT(*) FROM olist_DWH.dbo.Fact_Payments)               AS Fact_Payments,
    (SELECT COUNT(*) FROM olist_db.dbo.olist_order_reviews_dataset)  AS Source_Reviews,
    (SELECT COUNT(*) FROM olist_DWH.dbo.Fact_Reviews)                AS Fact_Reviews,
    (SELECT COUNT(*) FROM olist_db.dbo.olist_orders_dataset)         AS Source_Orders,
    (SELECT COUNT(*) FROM olist_DWH.dbo.Dim_Order)                   AS Dim_Orders;
GO

-- אין fan-out: הסכום זהה למקור
SELECT
    (SELECT SUM(payment_value) FROM olist_db.dbo.olist_order_payments_dataset) AS Source_Sum,
    (SELECT SUM(Payment_Value) FROM olist_DWH.dbo.Fact_Payments)               AS DWH_Sum;
GO

-- Dim_Customer בגרעין הנכון: מספר האנשים, לא מספר ההזמנות
SELECT
    (SELECT COUNT(DISTINCT customer_unique_id) FROM olist_db.dbo.olist_customers_dataset) AS Source_Unique_Customers,
    (SELECT COUNT(*) FROM olist_DWH.dbo.Dim_Customer)                                     AS DWH_Customers;
GO
