/* ============================================================================
   15_self_review_proofs.sql
   מטרה: הוכחה שהעיצוב המתוקן (Fact Constellation) פותר את 3 הפגמים
   שתועדו ב-05_analytical_flaws.sql - "לפני" (המקור, מדמה star ישן)
   מול "אחרי" (olist_DWH המתוקן).
   ============================================================================ */

-------------------------------------------------------------------
-- הוכחה 1: Payment_Value - מנופח (JOIN ישן ל-items) מול נכון (Fact_Payments)
-------------------------------------------------------------------
SELECT
    (SELECT SUM(pay.payment_value)
     FROM olist_db.dbo.olist_order_items_dataset oi
     JOIN olist_db.dbo.olist_order_payments_dataset pay ON oi.order_id = pay.order_id
    ) AS Old_Design_Inflated_Sum,
    (SELECT SUM(Payment_Value) FROM olist_DWH.dbo.Fact_Payments)               AS New_Design_Correct_Sum,
    (SELECT SUM(payment_value) FROM olist_db.dbo.olist_order_payments_dataset) AS True_Source_Sum;
GO

-------------------------------------------------------------------
-- הוכחה 2: ספירת לקוחות - order-scoped (ישן) מול person-scoped (חדש)
-------------------------------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT customer_id) FROM olist_db.dbo.olist_customers_dataset)        AS Old_Design_Customer_Count,
    (SELECT COUNT(*) FROM olist_DWH.dbo.Dim_Customer)                                     AS New_Design_Customer_Count,
    (SELECT COUNT(DISTINCT customer_unique_id) FROM olist_db.dbo.olist_customers_dataset) AS True_Unique_People;
GO

-------------------------------------------------------------------
-- הוכחה 3: ממוצע ציון ביקורת - משוקלל שגוי (ישן) מול לא-משוקלל נכון (חדש)
-------------------------------------------------------------------
SELECT
    (SELECT AVG(CAST(rev.review_score AS FLOAT))
     FROM olist_db.dbo.olist_order_items_dataset oi
     JOIN olist_db.dbo.olist_order_reviews_dataset rev ON oi.order_id = rev.order_id
    ) AS Old_Design_Weighted_By_Items_Avg,
    (SELECT AVG(CAST(Review_Score AS FLOAT)) FROM olist_DWH.dbo.Fact_Reviews) AS New_Design_Correct_Avg;
GO
