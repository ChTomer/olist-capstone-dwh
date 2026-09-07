/* ============================================================================
   14_demo_scd2_and_incremental.sql (מעודכן)
   מטרה: הדגמת SCD Type 2 וטעינה אינקרמנטלית. קובץ עצמאי, לא חלק מהצינור
   הראשי (שמתאים כי הדאטהסט היסטורי-סטטי).
   ============================================================================ */

USE olist_DWH;
GO

-------------------------------------------------------------------
-- הדגמה 1: SCD Type 2 על Dim_Seller (מדמה שינוי עיר של מוכר)
-------------------------------------------------------------------
ALTER TABLE dbo.Dim_Seller ADD Valid_From DATE DEFAULT '2016-01-01', Valid_To DATE NULL, Is_Current BIT DEFAULT 1;
GO

DECLARE @Seller_ID VARCHAR(50) = (SELECT TOP 1 Seller_ID FROM dbo.Dim_Seller);
DECLARE @New_City VARCHAR(100) = 'RIO DE JANEIRO';

UPDATE dbo.Dim_Seller SET Valid_To = GETDATE(), Is_Current = 0 WHERE Seller_ID = @Seller_ID AND Is_Current = 1;

INSERT INTO dbo.Dim_Seller (Seller_ID, City, State, Zip_Code, Country, Latitude, Longitude, Valid_From, Is_Current)
SELECT @Seller_ID, @New_City, State, Zip_Code, Country, Latitude, Longitude, GETDATE(), 1
FROM dbo.Dim_Seller WHERE Seller_ID = @Seller_ID AND Is_Current = 0;
GO

-------------------------------------------------------------------
-- הדגמה 2: טעינה אינקרמנטלית ל-Fact_Order_Items באמצעות MERGE + watermark
-- (הדגמה עקרונית מצומצמת, לא כל העמודות)
-------------------------------------------------------------------
ALTER TABLE dbo.Fact_Order_Items ADD Load_Date DATETIME2(0) DEFAULT SYSDATETIME();
GO

DECLARE @LastLoad DATETIME2(0) = (SELECT ISNULL(MAX(Load_Date), '2000-01-01') FROM dbo.Fact_Order_Items);

MERGE dbo.Fact_Order_Items AS tgt
USING (
    SELECT oi.order_id, oi.order_item_id, oi.price, oi.freight_value, o.order_purchase_timestamp
    FROM olist_STG.dbo.stg_order_items oi
    JOIN olist_STG.dbo.stg_orders o ON oi.order_id = o.order_id
    WHERE o.order_purchase_timestamp > @LastLoad
) AS src
ON tgt.Order_ID = src.order_id AND tgt.Order_Item_ID = src.order_item_id
WHEN NOT MATCHED THEN
    INSERT (Order_ID, Order_Item_ID, Price, Freight_Value, Load_Date)
    VALUES (src.order_id, src.order_item_id, src.price, src.freight_value, SYSDATETIME());
GO
