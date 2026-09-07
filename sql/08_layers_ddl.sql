/* ============================================================================
   08_layers_ddl.sql (מעודכן להתאמה למבנה בפועל אצלך)
   מטרה: DDL ל-olist_STG עם הגנות IF NOT EXISTS - תואם 1:1 לשמות/עמודות
   שכבר קיימים אצלך (קידומת stg_, snake_case, בלי city/state בגיאולוקציה).
   ============================================================================ */

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'olist_STG')
    CREATE DATABASE olist_STG;
GO
USE olist_STG;
GO

IF OBJECT_ID('dbo.stg_customers','U') IS NULL
CREATE TABLE dbo.stg_customers (
    customer_id                VARCHAR(50) NOT NULL,
    customer_unique_id         VARCHAR(50) NOT NULL,
    customer_city               VARCHAR(100),
    customer_state               VARCHAR(10),
    customer_zip_code_prefix      VARCHAR(10)
);
GO

IF OBJECT_ID('dbo.stg_geolocation','U') IS NULL
CREATE TABLE dbo.stg_geolocation (
    zip_code_prefix  VARCHAR(10),
    latitude          DECIMAL(10,8),
    longitude          DECIMAL(11,8)
);
GO

IF OBJECT_ID('dbo.stg_order_items','U') IS NULL
CREATE TABLE dbo.stg_order_items (
    order_id       VARCHAR(50) NOT NULL,
    order_item_id   INT NOT NULL,
    product_id       VARCHAR(50),
    seller_id         VARCHAR(50),
    price              DECIMAL(10,2),
    freight_value       DECIMAL(10,2)
);
GO

IF OBJECT_ID('dbo.stg_orders','U') IS NULL
CREATE TABLE dbo.stg_orders (
    order_id                        VARCHAR(50) NOT NULL,
    customer_id                      VARCHAR(50) NOT NULL,
    order_status                      VARCHAR(30),
    order_purchase_timestamp           DATETIME2(0),
    order_approved_at                   DATETIME2(0),
    order_delivered_carrier_date         DATETIME2(0),
    order_delivered_customer_date         DATETIME2(0),
    order_estimated_delivery_date          DATETIME2(0)
);
GO

IF OBJECT_ID('dbo.stg_payments','U') IS NULL
CREATE TABLE dbo.stg_payments (
    order_id              VARCHAR(50) NOT NULL,
    payment_sequential      INT NOT NULL,
    payment_type              VARCHAR(30),
    payment_installments        INT,
    payment_value                 DECIMAL(10,2)
);
GO

IF OBJECT_ID('dbo.stg_products','U') IS NULL
CREATE TABLE dbo.stg_products (
    product_id                  VARCHAR(50) NOT NULL,
    product_category_name        VARCHAR(100),
    product_category_name_eng     VARCHAR(100),
    product_weight_g                INT,
    product_length_cm                 INT,
    product_height_cm                   INT,
    product_width_cm                      INT
);
GO

IF OBJECT_ID('dbo.stg_reviews','U') IS NULL
CREATE TABLE dbo.stg_reviews (
    review_id      VARCHAR(50) NOT NULL,
    order_id        VARCHAR(50) NOT NULL,
    review_score      INT
);
GO

IF OBJECT_ID('dbo.stg_sellers','U') IS NULL
CREATE TABLE dbo.stg_sellers (
    seller_id                 VARCHAR(50) NOT NULL,
    seller_city                 VARCHAR(100),
    seller_state                  VARCHAR(10),
    seller_zip_code_prefix          VARCHAR(10)
);
GO
