/* ============================================================================
   11_etl_dimensions.sql (מעודכן)
   מטרה: טעינת הממדים ב-olist_DWH מתוך olist_STG, כולל Dim_Order
   (כתובת+סטטוס+מדדי איחור, גרעין = Order_ID).
   ============================================================================ */

USE olist_DWH;
GO

---------------------------------------------------
-- Dim_Date (2016-2020) - ממד סטטי, נטען פעם אחת בלבד
---------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.Dim_Date)
BEGIN
    DECLARE @StartDate DATE = '2016-01-01', @EndDate DATE = '2020-12-31';
    WHILE @StartDate <= @EndDate
    BEGIN
        INSERT INTO dbo.Dim_Date (Date_Key, Full_Date, Year, Quarter, Month, Month_Name, Day_Of_Week, Day_Name, Is_Weekend)
        VALUES (
            CAST(CONVERT(VARCHAR(8), @StartDate, 112) AS INT), @StartDate, YEAR(@StartDate),
            DATEPART(QUARTER, @StartDate), MONTH(@StartDate), DATENAME(MONTH, @StartDate),
            DATEPART(WEEKDAY, @StartDate), DATENAME(WEEKDAY, @StartDate),
            CASE WHEN DATEPART(WEEKDAY, @StartDate) IN (1,7) THEN 1 ELSE 0 END
        );
        SET @StartDate = DATEADD(DAY, 1, @StartDate);
    END
END;
GO

-- מרוקן קודם את ה-Fact tables - ייטענו מחדש בקובץ 12
TRUNCATE TABLE dbo.Fact_Order_Items;
TRUNCATE TABLE dbo.Fact_Payments;
TRUNCATE TABLE dbo.Fact_Reviews;
GO

-- טבלאות ה-Dim לא ניתנות ל-TRUNCATE - ב-SQL Server זה חסום ע"י עצם קיום
-- ה-FK מה-Fact tables, גם כשהן ריקות (לא תלוי בדאטה בפועל). משתמשים ב-DELETE
-- + איפוס ידני של ה-IDENTITY כדי שהמפתחות יתחילו מ-1 כמו TRUNCATE היה עושה.
DELETE FROM dbo.Dim_Customer;
DBCC CHECKIDENT ('dbo.Dim_Customer', RESEED, 0);
DELETE FROM dbo.Dim_Order;
DBCC CHECKIDENT ('dbo.Dim_Order', RESEED, 0);
DELETE FROM dbo.Dim_Seller;
DBCC CHECKIDENT ('dbo.Dim_Seller', RESEED, 0);
DELETE FROM dbo.Dim_Product;
DBCC CHECKIDENT ('dbo.Dim_Product', RESEED, 0);
GO

-- Dim_Customer: DISTINCT על customer_unique_id - תיקון פגם 3
INSERT INTO dbo.Dim_Customer (Customer_Unique_ID)
SELECT DISTINCT customer_unique_id
FROM olist_STG.dbo.stg_customers;
GO

WITH GeoAgg AS (
    SELECT zip_code_prefix, AVG(latitude) AS Latitude, AVG(longitude) AS Longitude
    FROM olist_STG.dbo.stg_geolocation
    GROUP BY zip_code_prefix
)
INSERT INTO dbo.Dim_Seller (Seller_ID, City, State, Zip_Code, Country, Latitude, Longitude)
SELECT s.seller_id, s.seller_city, s.seller_state, s.seller_zip_code_prefix, 'Brazil', g.Latitude, g.Longitude
FROM olist_STG.dbo.stg_sellers s
LEFT JOIN GeoAgg g ON s.seller_zip_code_prefix = g.zip_code_prefix;
GO

INSERT INTO dbo.Dim_Product (Product_ID, Category_Name_English, Product_Weight_g, Product_Length_cm, Product_Height_cm, Product_Width_cm)
SELECT product_id, product_category_name_eng, product_weight_g, product_length_cm, product_height_cm, product_width_cm
FROM olist_STG.dbo.stg_products;
GO

-- Dim_Order: גרעין = Order_ID. כתובת נלקחת מהלקוח בזמן ההזמנה
WITH GeoAgg AS (
    SELECT zip_code_prefix, AVG(latitude) AS Latitude, AVG(longitude) AS Longitude
    FROM olist_STG.dbo.stg_geolocation
    GROUP BY zip_code_prefix
)
INSERT INTO dbo.Dim_Order (Order_ID, Order_Status, City, State, Zip_Code, Country, Latitude, Longitude)
SELECT
    o.order_id, o.order_status, c.customer_city, c.customer_state, c.customer_zip_code_prefix, 'Brazil',
    g.Latitude, g.Longitude
FROM olist_STG.dbo.stg_orders o
LEFT JOIN olist_STG.dbo.stg_customers c ON o.customer_id = c.customer_id
LEFT JOIN GeoAgg g ON c.customer_zip_code_prefix = g.zip_code_prefix;
GO