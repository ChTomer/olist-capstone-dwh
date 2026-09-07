use olist_DWH

select top 10 * from Dim_Customer
select top 10 * from Dim_Date
select top 10 * from Dim_Order
select top 10 * from Dim_Order_Address
select top 10 * from Dim_Product
select top 10 * from Dim_Seller
select top 10 * from Fact_Order_Items
select top 10 * from Fact_Payments
select top 10 * from Fact_Reviews


select distinct Product_ID from Dim_Product
SELECT foi.* 
FROM Fact_Order_Items foi
JOIN Dim_Customer dc ON foi.Customer_Key = dc.Customer_Key
WHERE dc.Customer_Unique_ID IN (
'00053a61a98854899e70ed204dd4bafe'
,'0005e1862207bf6ccc02e4228effd9a0'
,'0005ef4cd20d2893f0d9fbd94d3c0d97'
,'0006fdc98a402fceb4eb0ee528f6a8d4'
,'00082cbe03e478190aadbea78542e933'
,'00090324bbad0e9342388303bb71ba0a'
,'000949456b182f53c18b68d6babc79c1'
,'000a5ad9c4601d2bbdd9ed765d5213b3'
,'000bfa1d2f1a41876493be685390d6d3'
,'000c8bdb58a29e7115cfc257230fb21b'
,'000d460961d6dbfa3ec6c9f5805769e1'
,'000de6019bb59f34c099a907c151d855'
,'000e309254ab1fc5ba99dd469d36bdb4'
,'000ec5bff359e1c0ad76a81a45cb598f')

use olist_STG
select distinct product_id from dbo.stg_products



USE olist_DWH;

-- הזמנות עם תשלום אבל בלי אף פריט
SELECT COUNT(DISTINCT p.Order_ID) AS Orders_Payment_No_Items,
       SUM(p.Payment_Value) AS Value_Payment_No_Items
FROM Fact_Payments p
LEFT JOIN Fact_Order_Items oi ON p.Order_ID = oi.Order_ID
WHERE oi.Order_ID IS NULL;

-- הזמנות עם פריטים אבל בלי תשלום
SELECT COUNT(DISTINCT oi.Order_ID) AS Orders_Items_No_Payment,
       SUM(oi.Price + oi.Freight_Value) AS Value_Items_No_Payment
FROM Fact_Order_Items oi
LEFT JOIN Fact_Payments p ON oi.Order_ID = p.Order_ID
WHERE p.Order_ID IS NULL;

SELECT o.order_status, COUNT(*) AS Cnt
FROM olist_STG.dbo.stg_orders o
GROUP BY o.order_status
ORDER BY Cnt DESC;

-- סטטוס של ההזמנות שיש להן תשלום בלי פריטים
SELECT o.order_status, COUNT(*) Cnt, SUM(p.Payment_Value) Total_Val
FROM Fact_Payments p
LEFT JOIN Fact_Order_Items oi ON p.Order_ID = oi.Order_ID
JOIN olist_STG.dbo.stg_orders o ON p.Order_ID = o.order_id
WHERE oi.Order_ID IS NULL
GROUP BY o.order_status;



USE olist_DWH;
SELECT COUNT(*) AS Total_Orders,
       COUNT(DISTINCT Order_ID) AS Distinct_Orders,
       (SELECT COUNT(DISTINCT Customer_ID) FROM Dim_Order_Address) AS Distinct_Addresses
FROM Dim_Order;



USE olist_DWH;
GO

-- ============================================
-- Edge Case Checks
-- ============================================

-- 0. שאלת המיזוג: Order_ID מול Customer_ID — 1:1?
SELECT COUNT(*) AS Total_Orders,
       COUNT(DISTINCT Order_ID) AS Distinct_Orders,
       (SELECT COUNT(DISTINCT Customer_ID) FROM Dim_Order_Address) AS Distinct_Addresses
FROM Dim_Order;

-- 1. הזמנות עם תאריך מסירה בפועל אך סטטוס שאינו delivered
SELECT dord.Order_Status, COUNT(*) Cnt
FROM Fact_Order_Items foi
JOIN Dim_Order dord ON foi.Order_Key = dord.Order_Key
WHERE foi.Delivered_Customer_Date IS NOT NULL AND dord.Order_Status <> 'delivered'
GROUP BY dord.Order_Status;

-- 2. ימי אספקה שליליים (משלוח לפני רכישה)
SELECT Order_ID, Purchase_Timestamp, Delivered_Customer_Date, Actual_Delivery_Days
FROM Fact_Order_Items
WHERE Actual_Delivery_Days < 0;

-- 3. Payment_Installments = 0, לפי Payment_Type
SELECT Payment_Type, COUNT(*) Cnt
FROM Fact_Payments
WHERE Payment_Installments = 0
GROUP BY Payment_Type;

-- 4. Review_Score ממוצע לפי Order_Status — לזהות אם ציונים נמוכים מגיעים מהזמנות שבוטלו
SELECT dord.Order_Status, AVG(CAST(fr.Review_Score AS FLOAT)) AS Avg_Score, COUNT(*) Cnt
FROM Fact_Reviews fr
JOIN Dim_Order dord ON fr.Order_Key = dord.Order_Key
GROUP BY dord.Order_Status
ORDER BY Avg_Score;

-- 5. Product_Key / Seller_Key חסרים, לפי סטטוס הזמנה
SELECT dord.Order_Status,
    SUM(CASE WHEN foi.Product_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Product,
    SUM(CASE WHEN foi.Seller_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Seller,
    COUNT(*) AS Total_Rows
FROM Fact_Order_Items foi
JOIN Dim_Order dord ON foi.Order_Key = dord.Order_Key
GROUP BY dord.Order_Status;
GO



select * from Dim_Customer dc
join Fact_Payments fp on dc.Customer_Key=fp.Customer_Key
select * from Fact_Payments

select max(Purchase_Date_Key)
from Fact_Payments





-- אין כפילויות גרעין בשום Fact (חייב להחזיר 0 שורות בכולן)
SELECT Order_ID, Order_Item_ID, COUNT(*) c FROM olist_DWH.dbo.Fact_Order_Items GROUP BY Order_ID, Order_Item_ID HAVING COUNT(*)>1;
SELECT Order_ID, Payment_Sequential, COUNT(*) c FROM olist_DWH.dbo.Fact_Payments GROUP BY Order_ID, Payment_Sequential HAVING COUNT(*)>1;
SELECT Review_ID, Order_ID, COUNT(*) c FROM olist_DWH.dbo.Fact_Reviews GROUP BY Review_ID, Order_ID HAVING COUNT(*)>1;
-- אין Review_ID+Order_ID עם ציונים סותרים
SELECT review_id, order_id, COUNT(DISTINCT review_score) c FROM olist_STG.dbo.stg_reviews GROUP BY review_id, order_id HAVING COUNT(DISTINCT review_score)>1;


select * from Fact_Payments


USE olist_DWH;
GO

-- ============================================
-- 1. אימות שתי הערים מה-Map Tooltip
-- ============================================
SELECT do.City, do.State,
    SUM(foi.Price) AS Items_Revenue,
    COUNT(DISTINCT foi.Seller_Key) AS Sellers_In_This_City
FROM Fact_Order_Items foi
JOIN Dim_Order do ON foi.Order_Key = do.Order_Key
WHERE do.City IN ('TRES CORACOES', 'OURO BRANCO')
GROUP BY do.City, do.State;

-- השוואה: כמה מוכרים שונים סה"כ מכרו למדינת MG (לבדוק אם 38 זה בעצם המספר הזה, לא ברמת עיר)
SELECT do.State,
    SUM(foi.Price) AS Items_Revenue,
    COUNT(DISTINCT foi.Seller_Key) AS Sellers_In_State
FROM Fact_Order_Items foi
JOIN Dim_Order do ON foi.Order_Key = do.Order_Key
WHERE do.State = 'MG'
GROUP BY do.State;

-- ============================================
-- 2. אימות שני המוכרים מה-Sellers Tooltip
-- ============================================
SELECT ds.Seller_ID,
    SUM(foi.Price) AS Seller_Revenue,
    COUNT(DISTINCT foi.Order_ID) AS Total_Orders_Items
FROM Fact_Order_Items foi
JOIN Dim_Seller ds ON foi.Seller_Key = ds.Seller_Key
WHERE ds.Seller_ID IN (
    '4869f7a5dfa277a7dca6462dcf3b52b2',
    '53243585a1d6dc2643021fd1853d8905'
)
GROUP BY ds.Seller_ID;
GO

select count(*) from Dim_Customer

use olist_DWH
-- חישוב דירוג ההזמנות אל מול ימי *האיחור* בפועל (בשונה מחישוב ימי ההזמנה)
SELECT
    CASE
        WHEN Delivery_Delay_Days BETWEEN 1 AND 3 THEN '1-3 delay days'
        WHEN Delivery_Delay_Days BETWEEN 4 AND 7 THEN '4-7 delay days'
        WHEN Delivery_Delay_Days BETWEEN 8 AND 14 THEN '8-14 delay days'
        ELSE '15+ delay days'
    END AS Delay_Severity,
    AVG(CAST(fr.Review_Score AS FLOAT)) AS Avg_Score,
    COUNT(*) AS Orders
FROM Fact_Order_Items foi
JOIN Fact_Reviews fr ON foi.Order_Key = fr.Order_Key
WHERE foi.Delivery_Delay_Days > 0
GROUP BY CASE
        WHEN Delivery_Delay_Days BETWEEN 1 AND 3 THEN '1-3 delay days'
        WHEN Delivery_Delay_Days BETWEEN 4 AND 7 THEN '4-7 delay days'
        WHEN Delivery_Delay_Days BETWEEN 8 AND 14 THEN '8-14 delay days'
        ELSE '15+ delay days'
    END
ORDER BY MIN(Delivery_Delay_Days);

USE olist_DWH;

WITH OrderDelay AS (
    -- כל הזמנה פעם אחת, עם ה-Delay שלה (Actual, לא מבואקט)
    SELECT DISTINCT Order_ID, Delivery_Delay_Days
    FROM Fact_Order_Items
    WHERE Delivery_Delay_Days IS NOT NULL
),
OrderReview AS (
    -- ממצע ביקורות כפולות באותה הזמנה קודם כל (כמו ב-Gemini)
    SELECT Order_ID, AVG(CAST(Review_Score AS FLOAT)) AS Avg_Score
    FROM Fact_Reviews
    GROUP BY Order_ID
)
SELECT
    od.Delivery_Delay_Days,                    -- ציר X: יום בודד, לא באקט
    AVG(orv.Avg_Score) AS Mean_Review_Score,   -- ציר Y: ממוצע בין הזמנות
    COUNT(*) AS Order_Count                    -- לגודל הנקודה + סינון רעש
FROM OrderDelay od
JOIN OrderReview orv ON od.Order_ID = orv.Order_ID
WHERE od.Delivery_Delay_Days BETWEEN -25 AND 25
GROUP BY od.Delivery_Delay_Days
HAVING COUNT(*) >= 30          -- בדיוק כמו הסינון של Gemini
ORDER BY od.Delivery_Delay_Days;


go
use olist_STG
select * from stg_orders
select DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date) from stg_orders
;

with cte as (
    select 
        CASE WHEN order_delivered_customer_date IS NOT NULL 
            THEN DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date) END as timediffs
    from stg_orders)
    select case when 
            timediffs < 0 then 'dont know'
            when timediffs <= 3 then '0-3'
            when timediffs <= 7 then '4-7'
            when timediffs <= 14 then '8-14'
            else '15+' end as bucket,
            count()
    from cte
    group by case when 
            timediffs < 0 then 'dont know'
            when timediffs <= 3 then '0-3'
            when timediffs <= 7 then '4-7'
            when timediffs <= 14 then '8-14'
            else '15+' end

        ISBLANK(ActualDays), "N/A",
    ActualDays <= 3, "0-3",
    ActualDays <= 7, "4-7",
    ActualDays <= 14, "8-14",


use olist_DWH
SELECT Duration_Band, COUNT(DISTINCT Duration_Band_Sort) AS Distinct_Sort_Values
FROM (
    SELECT
        CASE
            WHEN Actual_Delivery_Days IS NULL OR Actual_Delivery_Days <= 4 THEN NULL
            WHEN Actual_Delivery_Days <= 9 THEN '5-9d'
            WHEN Actual_Delivery_Days <= 14 THEN '10-14d'
            WHEN Actual_Delivery_Days <= 19 THEN '15-19d'
            WHEN Actual_Delivery_Days <= 24 THEN '20-24d'
            WHEN Actual_Delivery_Days <= 29 THEN '25-29d'
        END AS Duration_Band,
        CASE
            WHEN Actual_Delivery_Days IS NULL OR Actual_Delivery_Days <= 4 THEN NULL
            WHEN Actual_Delivery_Days <= 9 THEN 1
            WHEN Actual_Delivery_Days <= 14 THEN 2
            WHEN Actual_Delivery_Days <= 19 THEN 3
            WHEN Actual_Delivery_Days <= 24 THEN 4
            WHEN Actual_Delivery_Days <= 29 THEN 5
        END AS Duration_Band_Sort
    FROM olist_DWH.dbo.Fact_Order_Items
) t
WHERE Duration_Band IS NOT NULL
GROUP BY Duration_Band
HAVING COUNT(DISTINCT Duration_Band_Sort) > 1;