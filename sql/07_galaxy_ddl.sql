/* ============================================================================
   07_galaxy_ddl.sql (מעודכן להתאמה למבנה בפועל אצלך)
   מטרה: DDL ל-olist_DWH עם הגנות IF NOT EXISTS - לא יישבר על מה שכבר קיים.
   Dim_Order מחליף את Dim_Order_Address שהצעתי בהתחלה - הוא מאחד כתובת
   משלוח + סטטוס הזמנה + מדדי איחור, בגרעין Order_ID.
   ============================================================================ */

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'olist_DWH')
    CREATE DATABASE olist_DWH;
GO
USE olist_DWH;
GO

IF OBJECT_ID('dbo.Dim_Customer','U') IS NULL
CREATE TABLE dbo.Dim_Customer (
    Customer_Key       INT IDENTITY(1,1) PRIMARY KEY,
    Customer_Unique_ID VARCHAR(50) NOT NULL
);
GO

IF OBJECT_ID('dbo.Dim_Date','U') IS NULL
CREATE TABLE dbo.Dim_Date (
    Date_Key    INT PRIMARY KEY,
    Full_Date   DATE,
    Year        INT,
    Quarter     INT,
    Month       INT,
    Month_Name  VARCHAR(20),
    Day_Of_Week INT,
    Day_Name    VARCHAR(20),
    Is_Weekend  BIT
);
GO

-- גרעין = Order_ID. כתובת המשלוח (של הלקוח בזמן ההזמנה) + סטטוס + מדדי איחור
IF OBJECT_ID('dbo.Dim_Order','U') IS NULL
CREATE TABLE dbo.Dim_Order (
    Order_Key            INT IDENTITY(1,1) PRIMARY KEY,
    Order_ID              VARCHAR(50) NOT NULL,
    Order_Status          VARCHAR(20),
    City                  VARCHAR(100),
    State                 VARCHAR(10),
    Zip_Code               VARCHAR(10),
    Country                VARCHAR(30),
    Latitude               DECIMAL(10,8),
    Longitude               DECIMAL(11,8)
);
GO

IF OBJECT_ID('dbo.Dim_Product','U') IS NULL
CREATE TABLE dbo.Dim_Product (
    Product_Key           INT IDENTITY(1,1) PRIMARY KEY,
    Product_ID             VARCHAR(50) NOT NULL,
    Category_Name_English  VARCHAR(100),
    Product_Weight_g       INT,
    Product_Length_cm      INT,
    Product_Height_cm      INT,
    Product_Width_cm       INT
);
GO

IF OBJECT_ID('dbo.Dim_Seller','U') IS NULL
CREATE TABLE dbo.Dim_Seller (
    Seller_Key  INT IDENTITY(1,1) PRIMARY KEY,
    Seller_ID   VARCHAR(50) NOT NULL,
    City        VARCHAR(100),
    State       VARCHAR(10),
    Zip_Code    VARCHAR(10),
    Country     VARCHAR(30),
    Latitude    DECIMAL(10,8),
    Longitude   DECIMAL(11,8)
);
GO

IF OBJECT_ID('dbo.Fact_Order_Items','U') IS NULL
CREATE TABLE dbo.Fact_Order_Items (
    Fact_Key                 BIGINT IDENTITY(1,1) PRIMARY KEY,
    Order_ID                 VARCHAR(50) NOT NULL,
    Order_Item_ID             INT NOT NULL,
    Order_Key                 INT FOREIGN KEY REFERENCES dbo.Dim_Order(Order_Key),
    Customer_Key              INT FOREIGN KEY REFERENCES dbo.Dim_Customer(Customer_Key),
    Seller_Key                INT FOREIGN KEY REFERENCES dbo.Dim_Seller(Seller_Key),
    Product_Key               INT FOREIGN KEY REFERENCES dbo.Dim_Product(Product_Key),
    Purchase_Date_Key         INT FOREIGN KEY REFERENCES dbo.Dim_Date(Date_Key),
    Delivered_Date_Key        INT FOREIGN KEY REFERENCES dbo.Dim_Date(Date_Key),
    Purchase_Timestamp        DATETIME2(0),
    Delivered_Carrier_Date    DATETIME2(0),
    Delivered_Customer_Date   DATETIME2(0),
    Estimated_Delivery_Date   DATETIME2(0),
    Price                     DECIMAL(10,2),
    Freight_Value             DECIMAL(10,2),
    Delivery_Delay_Days       INT,
    Actual_Delivery_Days      INT
);
GO

IF OBJECT_ID('dbo.Fact_Payments','U') IS NULL
CREATE TABLE dbo.Fact_Payments (
    Fact_Key              BIGINT IDENTITY(1,1) PRIMARY KEY,
    Order_ID              VARCHAR(50) NOT NULL,
    Payment_Sequential    INT NOT NULL,
    Order_Key             INT FOREIGN KEY REFERENCES dbo.Dim_Order(Order_Key),
    Customer_Key          INT FOREIGN KEY REFERENCES dbo.Dim_Customer(Customer_Key),
    Purchase_Date_Key     INT FOREIGN KEY REFERENCES dbo.Dim_Date(Date_Key),
    Payment_Type          VARCHAR(30),
    Payment_Installments  INT,
    Payment_Value         DECIMAL(10,2)
);
GO

IF OBJECT_ID('dbo.Fact_Reviews','U') IS NULL
CREATE TABLE dbo.Fact_Reviews (
    Fact_Key           BIGINT IDENTITY(1,1) PRIMARY KEY,
    Review_ID          VARCHAR(50) NOT NULL,
    Order_ID           VARCHAR(50) NOT NULL,
    Order_Key          INT FOREIGN KEY REFERENCES dbo.Dim_Order(Order_Key),
    Customer_Key       INT FOREIGN KEY REFERENCES dbo.Dim_Customer(Customer_Key),
    Purchase_Date_Key  INT FOREIGN KEY REFERENCES dbo.Dim_Date(Date_Key),
    Review_Score       INT
);
GO

-- בדיקה מומלצת: ודא ש-DECIMAL אצלך לא נשאר DECIMAL(18,0) (0 ספרות אחרי הנקודה)
-- SELECT TABLE_NAME, COLUMN_NAME, NUMERIC_PRECISION, NUMERIC_SCALE
-- FROM INFORMATION_SCHEMA.COLUMNS WHERE DATA_TYPE = 'decimal';
