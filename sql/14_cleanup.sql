/* ============================================================================
   14_cleanup.sql
   מטרה: ביטול השינויים שקובץ 14 מבצע בסכימה - הרץ אחרי שסיימת להדגים/לצלם
   את התוצאה, כדי להחזיר את olist_DWH למבנה הנקי המקורי.
   אחרי הרצת הקובץ הזה - הרץ שוב 11 ו-12 כדי לרענן דאטה נקייה (זה גם
   מסלק את השורה הסינתטית "RIO DE JANEIRO" שנוספה ל-Dim_Seller).
   ============================================================================ */

USE olist_DWH;
GO

ALTER TABLE dbo.Dim_Seller DROP COLUMN Valid_From, Valid_To, Is_Current;
GO

ALTER TABLE dbo.Fact_Order_Items DROP COLUMN Load_Date;
GO

-- כעת הרץ שוב: 11_etl_dimensions.sql -> 12_etl_fact.sql (מרענן דאטה נקייה)
