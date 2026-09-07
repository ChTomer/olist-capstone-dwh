USE olist_STG;
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME, ORDINAL_POSITION;

USE olist_DWH;
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_NAME, ORDINAL_POSITION;

USE olist_db;
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('olist_products_dataset', 'product_category_name_translation')
ORDER BY TABLE_NAME, ORDINAL_POSITION;


SELECT SUM(Price) FROM olist_DWH.dbo.Fact_Order_Items;

SELECT
    YEAR(Purchase_Timestamp) AS Yr,
    MONTH(Purchase_Timestamp) AS Mo,
    COUNT(DISTINCT Order_ID) AS Orders,
    SUM(Price) AS Revenue
FROM olist_DWH.dbo.Fact_Order_Items
WHERE Purchase_Timestamp < '2017-01-01'
GROUP BY YEAR(Purchase_Timestamp), MONTH(Purchase_Timestamp)
ORDER BY Yr, Mo;


SELECT
    d.Year, d.Month,
    COUNT(DISTINCT fp.Order_ID) AS Orders,
    SUM(fp.Payment_Value) AS Net_Revenue
FROM olist_DWH.dbo.Fact_Payments fp
JOIN olist_DWH.dbo.Dim_Date d ON fp.Purchase_Date_Key = d.Date_Key
JOIN olist_DWH.dbo.Dim_Order do ON fp.Order_Key = do.Order_Key
WHERE do.Order_Status NOT IN ('canceled','unavailable')
  AND d.Full_Date < '2017-01-01'
GROUP BY d.Year, d.Month
ORDER BY d.Year, d.Month;


SELECT d.Full_Date, SUM(fp.Payment_Value) AS Daily_Revenue, COUNT(DISTINCT fp.Order_ID) AS Orders
FROM olist_DWH.dbo.Fact_Payments fp
JOIN olist_DWH.dbo.Dim_Date d ON fp.Purchase_Date_Key = d.Date_Key
JOIN olist_DWH.dbo.Dim_Order do ON fp.Order_Key = do.Order_Key
WHERE do.Order_Status NOT IN ('canceled','unavailable')
GROUP BY d.Full_Date
ORDER BY Daily_Revenue DESC;

use olist_DWH

select min(Review_Score),max(Review_Score), cast(AVG(Review_Score) as numeric (5,2))
from fact_reviews


select * from Fact_Reviews fr left join Dim_Customer dc  
on dc.Customer_Key=fr.Customer_Key


select count(*) - count(distinct Customer_Key) from Fact_Payments


select avg(Delivery_Delay_Days) from [dbo].[Fact_Order_Items]

select top 10 * from [dbo].[Fact_Order_Items]

select datediff(DAY,cast(Delivered_Customer_Date as date), cast(Purchase_Timestamp as date))*-1 from [dbo].[Fact_Order_Items]



-----------///////////////////////

-- ============================================
-- Independent Research Queries | olist_DWH
-- תחקיר עצמאי להיכרות מעמיקה עם הדאטה - לא מיועד לדשבורד
-- ============================================
USE olist_DWH;
GO

-- ============================================
-- 1. התנהגות לקוחות - כמה לקוחות חוזרים בכלל?
-- ============================================
SELECT
    COUNT(*) AS Repeat_Customers,
    (SELECT COUNT(DISTINCT Customer_Key) FROM Fact_Payments) AS Total_Customers,
    CAST(COUNT(*) AS FLOAT) / (SELECT COUNT(DISTINCT Customer_Key) FROM Fact_Payments) * 100 AS Pct_Repeat
FROM (
    SELECT Customer_Key, COUNT(DISTINCT Order_ID) AS Order_Count
    FROM Fact_Payments
    GROUP BY Customer_Key
    HAVING COUNT(DISTINCT Order_ID) > 1
) t;

-- זמן ממוצע בין הזמנה ראשונה לשנייה, אצל לקוחות חוזרים בלבד
WITH CustomerOrders AS (
    SELECT DISTINCT Customer_Key, Order_ID, Purchase_Timestamp
    FROM Fact_Order_Items
),
RankedOrders AS (
    SELECT Customer_Key, Order_ID, Purchase_Timestamp,
        ROW_NUMBER() OVER (PARTITION BY Customer_Key ORDER BY Purchase_Timestamp) AS rn
    FROM CustomerOrders
)
SELECT AVG(DATEDIFF(DAY, a.Purchase_Timestamp, b.Purchase_Timestamp)) AS Avg_Days_First_To_Second_Order
FROM RankedOrders a
JOIN RankedOrders b ON a.Customer_Key = b.Customer_Key AND a.rn = 1 AND b.rn = 2;


WITH CustomerOrders AS (
    SELECT DISTINCT Customer_Key, Order_ID, Purchase_Timestamp
    FROM Fact_Order_Items
),
RankedOrders AS (
    SELECT Customer_Key, Order_ID, Purchase_Timestamp,
        ROW_NUMBER() OVER (PARTITION BY Customer_Key ORDER BY Purchase_Timestamp) AS rn
    FROM CustomerOrders
)
SELECT DATEDIFF(DAY, a.Purchase_Timestamp, b.Purchase_Timestamp) AS Avg_Days_First_To_Second_Order
FROM RankedOrders a
JOIN RankedOrders b ON a.Customer_Key = b.Customer_Key AND a.rn = 1 AND b.rn = 2;

-- ============================================
-- 2. ריכוזיות עסקית (Pareto 80/20) - מוכרים
-- ============================================
WITH SellerRevenue AS (
    SELECT Seller_Key, SUM(Price) AS Revenue
    FROM Fact_Order_Items
    WHERE Seller_Key IS NOT NULL
    GROUP BY Seller_Key
),
Ranked AS (
    SELECT *, PERCENT_RANK() OVER (ORDER BY Revenue DESC) AS Pct_Rank
    FROM SellerRevenue
)
SELECT
    SUM(CASE WHEN Pct_Rank <= 0.2 THEN Revenue ELSE 0 END) AS Top20pct_Revenue,
    SUM(Revenue) AS Total_Revenue,
    CAST(SUM(CASE WHEN Pct_Rank <= 0.2 THEN Revenue ELSE 0 END) AS FLOAT) / SUM(Revenue) * 100 AS Pct_From_Top20_Sellers
FROM Ranked;

-- ריכוזיות לפי קטגוריית מוצר
WITH CategoryRevenue AS (
    SELECT dp.Category_Name_English, SUM(foi.Price) AS Revenue
    FROM Fact_Order_Items foi
    JOIN Dim_Product dp ON foi.Product_Key = dp.Product_Key
    GROUP BY dp.Category_Name_English
)
SELECT TOP 10 Category_Name_English, Revenue,
    CAST(Revenue AS FLOAT) / SUM(Revenue) OVER () * 100 AS Pct_Of_Total
FROM CategoryRevenue
ORDER BY Revenue DESC;

-- ============================================
-- 3. משלוחים - מעבר ל-SLA
-- ============================================

-- זמן אישור תשלום (approval) - שלב נפרד מזמן המשלוח עצמו
-- שים לב: order_approved_at לא בשכבת ה-DWH, שאילתה זו על ה-STG
SELECT AVG(DATEDIFF(MINUTE, order_purchase_timestamp, order_approved_at)) AS Avg_Approval_Minutes
FROM olist_STG.dbo.stg_orders
WHERE order_approved_at IS NOT NULL;

-- מרחק גיאוגרפי (גס, במעלות lat/long) מול זמן משלוח
WITH OrderDistance AS (
    SELECT DISTINCT foi.Order_ID, foi.Order_Key,
        SQRT(POWER(do.Latitude - ds.Latitude, 2) + POWER(do.Longitude - ds.Longitude, 2)) AS Distance_Deg
    FROM Fact_Order_Items foi
    JOIN Dim_Order do ON foi.Order_Key = do.Order_Key
    JOIN Dim_Seller ds ON foi.Seller_Key = ds.Seller_Key
    WHERE do.Latitude IS NOT NULL AND ds.Latitude IS NOT NULL
)
SELECT
    CASE
        WHEN od.Distance_Deg <= 5 THEN '0-5'
        WHEN od.Distance_Deg <= 15 THEN '5-15'
        WHEN od.Distance_Deg <= 30 THEN '15-30'
        ELSE '30+'
    END AS Distance_Bucket_Degrees,
    AVG(do.Actual_Delivery_Days) AS Avg_Delivery_Days,
    COUNT(*) AS Orders
FROM OrderDistance od
JOIN Dim_Order do ON od.Order_Key = do.Order_Key
GROUP BY CASE
        WHEN od.Distance_Deg <= 5 THEN '0-5'
        WHEN od.Distance_Deg <= 15 THEN '5-15'
        WHEN od.Distance_Deg <= 30 THEN '15-30'
        ELSE '30+'
    END
ORDER BY MIN(od.Distance_Deg);

-- אותה מדינה מול מדינה שונה (לקוח-מוכר)
SELECT
    CASE WHEN do.State = ds.State THEN 'Same State' ELSE 'Cross State' END AS Route_Type,
    AVG(do.Actual_Delivery_Days) AS Avg_Delivery_Days,
    COUNT(DISTINCT foi.Order_ID) AS Orders
FROM Fact_Order_Items foi
JOIN Dim_Order do ON foi.Order_Key = do.Order_Key
JOIN Dim_Seller ds ON foi.Seller_Key = ds.Seller_Key
GROUP BY CASE WHEN do.State = ds.State THEN 'Same State' ELSE 'Cross State' END;

-- ============================================
-- 4. תמחור ומשלוח
-- ============================================

-- Freight כאחוז מ-Price, לפי קטגוריה
SELECT dp.Category_Name_English,
    AVG(foi.Price) AS Avg_Price,
    AVG(foi.Freight_Value) AS Avg_Freight,
    AVG(foi.Freight_Value / NULLIF(foi.Price, 0)) * 100 AS Avg_Freight_Pct_Of_Price
FROM Fact_Order_Items foi
JOIN Dim_Product dp ON foi.Product_Key = dp.Product_Key
GROUP BY dp.Category_Name_English
ORDER BY Avg_Freight_Pct_Of_Price DESC;

-- משקל מול עלות משלוח (בדיקת הגיון)
SELECT
    CASE
        WHEN dp.Product_Weight_g <= 500 THEN '0-500g'
        WHEN dp.Product_Weight_g <= 2000 THEN '500-2000g'
        WHEN dp.Product_Weight_g <= 5000 THEN '2000-5000g'
        ELSE '5000g+'
    END AS Weight_Bucket,
    AVG(foi.Freight_Value) AS Avg_Freight,
    COUNT(*) AS Items
FROM Fact_Order_Items foi
JOIN Dim_Product dp ON foi.Product_Key = dp.Product_Key
WHERE dp.Product_Weight_g IS NOT NULL
GROUP BY CASE
        WHEN dp.Product_Weight_g <= 500 THEN '0-500g'
        WHEN dp.Product_Weight_g <= 2000 THEN '500-2000g'
        WHEN dp.Product_Weight_g <= 5000 THEN '2000-5000g'
        ELSE '5000g+'
    END
ORDER BY MIN(dp.Product_Weight_g);

-- ============================================
-- 5. תשלומים - Installments מול גובה ההזמנה
-- ============================================
SELECT
    CASE
        WHEN Payment_Value <= 50 THEN '0-50'
        WHEN Payment_Value <= 150 THEN '50-150'
        WHEN Payment_Value <= 300 THEN '150-300'
        ELSE '300+'
    END AS Value_Bucket,
    AVG(Payment_Installments) AS Avg_Installments,
    COUNT(*) AS Payments
FROM Fact_Payments
WHERE Payment_Type = 'credit_card'
GROUP BY CASE
        WHEN Payment_Value <= 50 THEN '0-50'
        WHEN Payment_Value <= 150 THEN '50-150'
        WHEN Payment_Value <= 300 THEN '150-300'
        ELSE '300+'
    END
ORDER BY MIN(Payment_Value);

-- ============================================
-- 6. עונתיות - מעבר ל-Black Friday שכבר נמצא
-- ============================================

-- דפוס לפי יום בשבוע
SELECT d.Day_Name, AVG(daily.Daily_Revenue) AS Avg_Revenue_By_DOW
FROM (
    SELECT fp.Purchase_Date_Key, SUM(fp.Payment_Value) AS Daily_Revenue
    FROM Fact_Payments fp
    GROUP BY fp.Purchase_Date_Key
) daily
JOIN Dim_Date d ON daily.Purchase_Date_Key = d.Date_Key
GROUP BY d.Day_Name
ORDER BY Avg_Revenue_By_DOW DESC;

-- בדיקת יום האם הברזילאי (יום ראשון שני של מאי) - אירוע קניות ידוע בברזיל
SELECT d.Full_Date, SUM(fp.Payment_Value) AS Daily_Revenue, COUNT(DISTINCT fp.Order_ID) AS Orders
FROM Fact_Payments fp
JOIN Dim_Date d ON fp.Purchase_Date_Key = d.Date_Key
WHERE d.Month = 5 AND d.Year IN (2017, 2018)
GROUP BY d.Full_Date
ORDER BY Daily_Revenue DESC;
GO




-- ============================================
-- 7. בדיקה ממוקדת: יום האם הברזילאי מול ממוצע החודש
-- ============================================

-- שלב א': ממוצע הכנסה יומית "רגיל" לכל חודש מאי (לא כולל השבועיים שלפני החג)
WITH DailyRevenue AS (
    SELECT d.Full_Date, d.Year, d.Month, DAY(d.Full_Date) AS Day_Of_Month,
           SUM(fp.Payment_Value) AS Daily_Revenue
    FROM Fact_Payments fp
    JOIN Dim_Date d ON fp.Purchase_Date_Key = d.Date_Key
    WHERE d.Month = 5 AND d.Year IN (2017, 2018)
    GROUP BY d.Full_Date, d.Year, d.Month
)
SELECT
    Year,
    AVG(CASE WHEN Day_Of_Month NOT BETWEEN 1 AND 14 THEN Daily_Revenue END) AS Avg_Baseline_Rest_Of_Month,
    AVG(CASE WHEN Day_Of_Month BETWEEN 1 AND 14 THEN Daily_Revenue END) AS Avg_First_Two_Weeks,
    MAX(CASE WHEN (Year = 2017 AND Day_Of_Month = 14) OR (Year = 2018 AND Day_Of_Month = 13)
             THEN Daily_Revenue END) AS Mothers_Day_Revenue
FROM DailyRevenue
GROUP BY Year;

-- שלב ב': פירוט יומי מלא ל-16 הימים הראשונים של מאי, לשתי השנים - לזיהוי מגמת עלייה לפני החג
SELECT d.Year, DAY(d.Full_Date) AS Day_Of_Month, d.Full_Date, SUM(fp.Payment_Value) AS Daily_Revenue
FROM Fact_Payments fp
JOIN Dim_Date d ON fp.Purchase_Date_Key = d.Date_Key
WHERE d.Month = 5 AND DAY(d.Full_Date) BETWEEN 1 AND 16 AND d.Year IN (2017, 2018)
GROUP BY d.Year, DAY(d.Full_Date), d.Full_Date
ORDER BY d.Year, Day_Of_Month;




SELECT review_id, order_id, COUNT(*) c
FROM olist_STG.dbo.stg_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;


select count(*) from Dim_Customer
select count(*) from Dim_Date
select count(*) from [dbo].[Dim_Order]
select count(*) from Dim_Product
select count(*) from Dim_Seller
select count(*) from Fact_Order_Items
select count(*) from Fact_Payments
select count(*) from Fact_Reviews
;
select count(distinct Customer_Key) from dim_customer
select count(distinct Date_Key) as d_key from Dim_Date
select count(distinct [Order_Key]) as d_key from [dbo].[Dim_Order]
select count(distinct [Product_Key]) as d_key from Dim_Product
select count(distinct [Seller_Key]) as d_key from Dim_Seller
select count(distinct [Fact_Key]) as d_key from Fact_Order_Items
select count(distinct [Fact_Key]) as d_key from Fact_Payments
select count(distinct [Fact_Key]) as d_key from Fact_Reviews

select 
    count(*) totl_rows, 
    count(distinct review_id) D_review_ids, 
    count(distinct order_id) D_order_idss,
    count(*) - count(distinct review_id) more_than_1
from Fact_Reviews

SELECT COUNT(*) FROM olist_STG.dbo.stg_payments p
LEFT JOIN olist_STG.dbo.stg_orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

use olist_db
select 
count(distinct Customer_Unique_ID) unique_id,
count(distinct Customer_id) cus_id from [dbo].[olist_customers_dataset]


USE olist_DWH;
SELECT Category_Name_English, COUNT(*) AS Products, 
       SUM(f.Price) AS Revenue
FROM dbo.Dim_Product p
JOIN dbo.Fact_Order_Items f ON p.Product_Key = f.Product_Key
GROUP BY Category_Name_English
ORDER BY Revenue DESC;
אחד מציג את רמת ההזמנה 

USE olist_DWH;
GO

-- ============================================
-- Data Quality Checks | DWH v2 (Fact Constellation)
-- ============================================

-- 1. השוואת ספירות שורות מול המקור — כל Fact מול ה-STG המקביל
SELECT
    (SELECT COUNT(*) FROM olist_STG.dbo.stg_order_items) AS STG_Items,
    (SELECT COUNT(*) FROM Fact_Order_Items) AS Fact_Items,
    (SELECT COUNT(*) FROM olist_STG.dbo.stg_payments) AS STG_Payments,
    (SELECT COUNT(*) FROM Fact_Payments) AS Fact_Payments,
    (SELECT COUNT(*) FROM olist_STG.dbo.stg_reviews) AS STG_Reviews,
    (SELECT COUNT(*) FROM Fact_Reviews) AS Fact_Reviews;

-- 2. סכום Payment_Value: STG מול Fact_Payments — חייב להיות זהה (0 ניפוח)
SELECT
    (SELECT SUM(payment_value) FROM olist_STG.dbo.stg_payments) AS STG_Total,
    (SELECT SUM(Payment_Value) FROM Fact_Payments) AS Fact_Total;

-- 3. Review_Score ממוצע: STG מול Fact_Reviews — חייב להיות זהה (בלי הטיה)
SELECT
    (SELECT AVG(CAST(review_score AS FLOAT)) FROM olist_STG.dbo.stg_reviews) AS STG_Avg,
    (SELECT AVG(CAST(Review_Score AS FLOAT)) FROM Fact_Reviews) AS Fact_Avg;

-- 4. FK-ים חסרים בכל אחת מה-Facts
SELECT 'Fact_Order_Items' AS Tbl,
    SUM(CASE WHEN Customer_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Customer,
    SUM(CASE WHEN Order_Address_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Address,
    SUM(CASE WHEN Seller_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Seller,
    SUM(CASE WHEN Product_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Product
FROM Fact_Order_Items;

SELECT 'Fact_Payments' AS Tbl,
    SUM(CASE WHEN Customer_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Customer
FROM Fact_Payments;

SELECT 'Fact_Reviews' AS Tbl,
    SUM(CASE WHEN Customer_Key IS NULL THEN 1 ELSE 0 END) AS Missing_Customer
FROM Fact_Reviews;

-- 5. וידוא Grain: אין כפילויות במפתח הטבעי של כל Fact
SELECT 'Fact_Order_Items dup' AS Chk, Order_ID, Order_Item_ID, COUNT(*) c
FROM Fact_Order_Items GROUP BY Order_ID, Order_Item_ID HAVING COUNT(*) > 1;

SELECT 'Fact_Payments dup' AS Chk, Order_ID, Payment_Sequential, COUNT(*) c
FROM Fact_Payments GROUP BY Order_ID, Payment_Sequential HAVING COUNT(*) > 1;

SELECT 'Fact_Reviews dup' AS Chk, Review_ID, Order_ID, COUNT(*) c
FROM Fact_Reviews GROUP BY Review_ID, Order_ID HAVING COUNT(*) > 1;

-- 6. וידוא Dim_Customer: אין כפילויות ב-Customer_Unique_ID
SELECT Customer_Unique_ID, COUNT(*) c FROM Dim_Customer
GROUP BY Customer_Unique_ID HAVING COUNT(*) > 1;
GO




USE olist_DWH;
GO

-- 1. הסרת הכפילות מ-Dim_Order
ALTER TABLE dbo.Dim_Order
DROP COLUMN Delivery_Delay_Days, Actual_Delivery_Days;
GO

-- 2. הוספת Delivered_Date_Key ל-Fact_Order_Items
ALTER TABLE dbo.Fact_Order_Items ADD Delivered_Date_Key INT NULL;
GO

UPDATE dbo.Fact_Order_Items
SET Delivered_Date_Key = CAST(CONVERT(VARCHAR(8), Delivered_Customer_Date, 112) AS INT)
WHERE Delivered_Customer_Date IS NOT NULL;
GO

ALTER TABLE dbo.Fact_Order_Items
ADD CONSTRAINT FK_FactOrderItems_DeliveredDate
FOREIGN KEY (Delivered_Date_Key) REFERENCES dbo.Dim_Date(Date_Key);
GO

USE olist_DWH;
GO

-- 1. Fact_Order_Items אמור להיות 112,650 שורות (grain = order_item)
SELECT COUNT(*) AS Row_Count FROM dbo.Fact_Order_Items;

-- 2. Dim_Order - לוודא ששתי העמודות באמת נעלמו
SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Dim_Order' AND COLUMN_NAME IN ('Delivery_Delay_Days','Actual_Delivery_Days');
-- אמור להחזיר 0 שורות

-- 3. Fact_Order_Items - Delivered_Date_Key קיים פעם אחת + ה-FK תקין
SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Fact_Order_Items' AND COLUMN_NAME = 'Delivered_Date_Key';
-- אמור להחזיר 1

SELECT COUNT(*) FROM sys.foreign_keys WHERE name = 'FK_FactOrderItems_DeliveredDate';
-- אמור להחזיר 1



USE olist_DWH;
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
ORDER BY TABLE_NAME, ORDINAL_POSITION;


SELECT COUNT(*) AS Delivered_But_No_Delivery_Date
FROM olist_DWH.dbo.Dim_Order
WHERE Actual_Delivery_Days IS NULL AND Order_Status = 'delivered';

USE olist_DWH;
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('Actual_Delivery_Days','Delivery_Delay_Days')
ORDER BY TABLE_NAME;

SELECT COUNT(*) AS Delivered_But_No_Delivery_Date
FROM olist_DWH.dbo.Fact_Order_Items foi
JOIN olist_DWH.dbo.Dim_Order dord ON foi.Order_Key = dord.Order_Key
WHERE foi.Actual_Delivery_Days IS NULL AND dord.Order_Status = 'delivered';

USE olist_DWH;
WITH OrderDelivery AS (
    SELECT dord.Order_ID,
        MAX(foi.Actual_Delivery_Days) AS Actual_Delivery_Days
    FROM Dim_Order dord
    LEFT JOIN Fact_Order_Items foi ON dord.Order_Key = foi.Order_Key
    GROUP BY dord.Order_ID
),
Bucketed AS (
    SELECT Order_ID,
        CASE WHEN Actual_Delivery_Days IS NULL THEN 'N/A'
             WHEN Actual_Delivery_Days <= 3 THEN '0-3'
             WHEN Actual_Delivery_Days <= 7 THEN '4-7'
             WHEN Actual_Delivery_Days <= 14 THEN '8-14'
             ELSE '15+' END AS Bucket
    FROM OrderDelivery
)
SELECT b.Bucket, AVG(CAST(fr.Review_Score AS FLOAT)) AS Avg_Score, COUNT(*) Cnt
FROM Bucketed b
JOIN Fact_Reviews fr ON b.Order_ID = fr.Order_ID
GROUP BY b.Bucket
ORDER BY Avg_Score;