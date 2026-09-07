/* ============================================================================
   02_load_source_data.sql
   מטרה: טעינת קבצי ה-CSV הגולמיים ל-olist_db באמצעות BULK INSERT ישיר בקוד
   (ולא Import Flat File Wizard) - כך שהתהליך ניתן להרצה חוזרת ומתועד במלואו.

   ⚠ הערה קריטית - נתיב ה-CSV נמצא תחת OneDrive:
   C:\Users\tomer\OneDrive\Desktop\olist
   אם הקבצים מוגדרים כ"Files On-Demand" (ענן בלבד, לא מסונכרנים פיזית),
   BULK INSERT ייכשל כי שירות SQL Server לא רואה קובץ אמיתי על הדיסק.
   1) ודא: קליק ימני על התיקייה > "Always keep on this device"
   2) ודא ששירות SQL Server (בד"כ NT SERVICE\MSSQLSERVER) יש לו הרשאת קריאה
      לנתיב - תיקיות משתמש לפעמים חסומות לחשבון השירות.
   אם יש בעיות מתמשכות - הפתרון הפשוט ביותר: להעתיק את קבצי ה-CSV לנתיב
   מקומי "נקי" כמו C:\SQLData\olist ולעדכן את הנתיבים למטה.

   הערות טכניות נוספות:
   - FORMAT='CSV' מטפל נכון במרכאות ופסיקים בתוך שדות טקסט (למשל בביקורות)
   - CODEPAGE='65001' (UTF-8) נדרש בגלל תווי פורטוגזית (á, ã, ç, ...)
   - ROWTERMINATOR='0x0a' כי קבצי Kaggle מגיעים בד"כ בסגנון שבירת שורה Unix.
     אם ההרצה נכשלת על "unexpected row length" - נסה '\n' או ברירת המחדל.
   ============================================================================ */

USE olist_db;
GO

BULK INSERT dbo.olist_customers_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_customers_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.olist_geolocation_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_geolocation_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.olist_orders_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_orders_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.olist_order_items_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_order_items_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.olist_order_payments_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_order_payments_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.olist_order_reviews_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_order_reviews_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.olist_products_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_products_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.olist_sellers_dataset
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\olist_sellers_dataset.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO

BULK INSERT dbo.product_category_name_translation
FROM 'C:\Users\tomer\OneDrive\Desktop\olist\product_category_name_translation.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDQUOTE='"', CODEPAGE='65001', ROWTERMINATOR='0x0a', TABLOCK);
GO
