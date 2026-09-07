/* ============================================================================
   01_create_source_db.sql
   מטרה: יצירת מסד המקור (olist_db) - מראה (mirror) גולמית של קבצי ה-CSV
   מ-Kaggle, ללא לוגיקה עסקית וללא ניקוי.
   עקרון: טיפוסי הנתונים משקפים את הפורמט הגולמי של ה-CSV, לא את הסכימה
   הסופית ב-DWH. אין PK/FK/אינדקסים בקובץ זה - ר' 04_constraints_and_indexes.sql
   ============================================================================ */

CREATE DATABASE olist_db;
GO

USE olist_db;
GO

-- customer_id הוא PK תפעולי (order-scoped, לא זהות אדם).
-- customer_unique_id הוא זיהוי האדם האמיתי - ר' ניתוח הפגם ב-05_analytical_flaws.sql
CREATE TABLE dbo.olist_customers_dataset (
    customer_id                VARCHAR(50)     NOT NULL,
    customer_unique_id         VARCHAR(50)     NOT NULL,
    customer_zip_code_prefix   INT             NULL,
    customer_city              NVARCHAR(100)   NULL,
    customer_state             VARCHAR(2)      NULL
);
GO

CREATE TABLE dbo.olist_geolocation_dataset (
    geolocation_zip_code_prefix    INT             NULL,
    geolocation_lat                DECIMAL(10,8)   NULL,
    geolocation_lng                DECIMAL(11,8)   NULL,
    geolocation_city               NVARCHAR(100)   NULL,
    geolocation_state              VARCHAR(2)      NULL
);
GO

CREATE TABLE dbo.olist_orders_dataset (
    order_id                       VARCHAR(50)     NOT NULL,
    customer_id                    VARCHAR(50)     NOT NULL,
    order_status                   VARCHAR(20)     NULL,
    order_purchase_timestamp       DATETIME2(0)    NULL,
    order_approved_at              DATETIME2(0)    NULL,
    order_delivered_carrier_date   DATETIME2(0)    NULL,
    order_delivered_customer_date  DATETIME2(0)    NULL,
    order_estimated_delivery_date  DATETIME2(0)    NULL
);
GO

-- ה-grain האמיתי של שורת מכירה הוא order_id + order_item_id, לא order_id לבד
CREATE TABLE dbo.olist_order_items_dataset (
    order_id                VARCHAR(50)     NOT NULL,
    order_item_id           INT             NOT NULL,
    product_id              VARCHAR(50)     NULL,
    seller_id               VARCHAR(50)     NULL,
    shipping_limit_date     DATETIME2(0)    NULL,
    price                   DECIMAL(10,2)   NULL,
    freight_value           DECIMAL(10,2)   NULL
);
GO

-- ה-grain הוא order_id + payment_sequential - להזמנה אחת יכולים להיות כמה תשלומים
CREATE TABLE dbo.olist_order_payments_dataset (
    order_id                VARCHAR(50)     NOT NULL,
    payment_sequential      INT             NOT NULL,
    payment_type            VARCHAR(20)     NULL,
    payment_installments    INT             NULL,
    payment_value           DECIMAL(10,2)   NULL
);
GO

-- ה-grain הוא review_id - הזמנה אחת יכולה לקבל כמה ביקורות (fan-out קלאסי)
CREATE TABLE dbo.olist_order_reviews_dataset (
    review_id                VARCHAR(50)     NOT NULL,
    order_id                 VARCHAR(50)     NOT NULL,
    review_score             TINYINT         NULL,
    review_comment_title     NVARCHAR(200)   NULL,
    review_comment_message   NVARCHAR(4000)  NULL,
    review_creation_date     DATETIME2(0)    NULL,
    review_answer_timestamp  DATETIME2(0)    NULL
);
GO

CREATE TABLE dbo.olist_products_dataset (
    product_id                   VARCHAR(50)    NOT NULL,
    product_category_name        NVARCHAR(100)  NULL,
    product_name_lenght          INT            NULL,  -- שגיאת כתיב מקורית של Kaggle - נשמרת כמו שהיא בשכבת המקור
    product_description_lenght   INT            NULL,
    product_photos_qty           INT            NULL,
    product_weight_g             INT            NULL,
    product_length_cm            INT            NULL,
    product_height_cm            INT            NULL,
    product_width_cm             INT            NULL
);
GO

CREATE TABLE dbo.olist_sellers_dataset (
    seller_id                VARCHAR(50)    NOT NULL,
    seller_zip_code_prefix   INT            NULL,
    seller_city               NVARCHAR(100) NULL,
    seller_state              VARCHAR(2)    NULL
);
GO

CREATE TABLE dbo.product_category_name_translation (
    product_category_name          NVARCHAR(100)  NULL,
    product_category_name_english  NVARCHAR(100)  NULL
);
GO
