/* ============================================================================
   09_etl_mirror.sql
   מטרה: עטיפת התהליך של 01+02 בפרוצדורה הניתנת להרצה חוזרת - מרוקנת
   ומטעינה מחדש את שכבת המקור (olist_db) מה-CSV. מוכיח שהתהליך כולו ניתן
   לשחזור מלא (rebuild) בהרצה אחת.
   ============================================================================ */

USE olist_db;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RefreshSourceMirror
    @CsvPath NVARCHAR(260) = 'C:\Users\tomer\OneDrive\Desktop\olist\'
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dbo.olist_order_reviews_dataset;
    TRUNCATE TABLE dbo.olist_order_payments_dataset;
    TRUNCATE TABLE dbo.olist_order_items_dataset;
    TRUNCATE TABLE dbo.olist_orders_dataset;
    TRUNCATE TABLE dbo.olist_customers_dataset;
    TRUNCATE TABLE dbo.olist_geolocation_dataset;
    TRUNCATE TABLE dbo.olist_products_dataset;
    TRUNCATE TABLE dbo.olist_sellers_dataset;
    TRUNCATE TABLE dbo.product_category_name_translation;

    -- BULK INSERT לא תומך במשתנה ישירות ב-FROM, לכן SQL דינמי דרך טבלת מיפוי
    DECLARE @tbl TABLE (TableName SYSNAME, FileName_ SYSNAME);
    INSERT INTO @tbl VALUES
        ('olist_customers_dataset','olist_customers_dataset.csv'),
        ('olist_geolocation_dataset','olist_geolocation_dataset.csv'),
        ('olist_orders_dataset','olist_orders_dataset.csv'),
        ('olist_order_items_dataset','olist_order_items_dataset.csv'),
        ('olist_order_payments_dataset','olist_order_payments_dataset.csv'),
        ('olist_order_reviews_dataset','olist_order_reviews_dataset.csv'),
        ('olist_products_dataset','olist_products_dataset.csv'),
        ('olist_sellers_dataset','olist_sellers_dataset.csv'),
        ('product_category_name_translation','product_category_name_translation.csv');

    DECLARE @t SYSNAME, @f SYSNAME, @sql NVARCHAR(MAX);
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, FileName_ FROM @tbl;
    OPEN c;
    FETCH NEXT FROM c INTO @t, @f;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'BULK INSERT dbo.' + QUOTENAME(@t) + N' FROM ''' + @CsvPath + @f + N'''
            WITH (FORMAT=''CSV'', FIRSTROW=2, FIELDQUOTE=''"'', CODEPAGE=''65001'', ROWTERMINATOR=''0x0a'', TABLOCK);';
        EXEC sp_executesql @sql;
        FETCH NEXT FROM c INTO @t, @f;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

-- הרצה: EXEC dbo.usp_RefreshSourceMirror;
