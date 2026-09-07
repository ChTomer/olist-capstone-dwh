/* ============================================================================
   05_analytical_flaws.sql
   מטרה: הוכחה בשאילתות של 3 הפגמים שהתגלו בעיצוב ה-Fact_Sales המקורי
   (star יחיד ברמת item), שהובילו למעבר לגלקסיה עם 3 טבלאות עובדה נפרדות.
   ============================================================================ */

USE olist_db;
GO

-------------------------------------------------------------------
-- פגם 1: Fan-out של תשלומים. אם מצרפים payments (ברמת order) לטבלת
-- items (ברמת item), כל שורת תשלום מוכפלת במספר הפריטים -> סכום מנופח
-------------------------------------------------------------------
SELECT COUNT(*) AS Orders_With_Multiple_Payments
FROM (SELECT order_id FROM dbo.olist_order_payments_dataset GROUP BY order_id HAVING COUNT(*) > 1) x;

SELECT
    (SELECT SUM(payment_value) FROM dbo.olist_order_payments_dataset) AS Correct_Total_Payments,
    (SELECT SUM(pay.payment_value)
     FROM dbo.olist_order_items_dataset oi
     JOIN dbo.olist_order_payments_dataset pay ON oi.order_id = pay.order_id
    ) AS Inflated_Total_If_Joined_To_Items;
GO

-------------------------------------------------------------------
-- פגם 2: Fan-out של ביקורות - הזמנות עם יותר מביקורת אחת
-------------------------------------------------------------------
SELECT COUNT(*) AS Orders_With_Multiple_Reviews
FROM (SELECT order_id FROM dbo.olist_order_reviews_dataset GROUP BY order_id HAVING COUNT(*) > 1) x;
GO

-------------------------------------------------------------------
-- פגם 3: customer_id (order-scoped) מול customer_unique_id (person-scoped)
-------------------------------------------------------------------
SELECT
    COUNT(DISTINCT customer_id)        AS Distinct_Customer_ID,
    COUNT(DISTINCT customer_unique_id) AS Distinct_Customer_Unique_ID,
    COUNT(DISTINCT customer_id) - COUNT(DISTINCT customer_unique_id) AS Difference
FROM dbo.olist_customers_dataset;
GO
