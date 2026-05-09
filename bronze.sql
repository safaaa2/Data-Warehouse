CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO



USE DataWarehouse;
GO

SELECT name, schema_id 
FROM sys.schemas
WHERE name IN ('bronze', 'silver', 'gold');




USE DataWarehouse;
GO

IF OBJECT_ID('bronze.account', 'U') IS NOT NULL DROP TABLE bronze.account;
CREATE TABLE bronze.account (
    account_number  NVARCHAR(50),
    account_name    NVARCHAR(100),
    account_type    NVARCHAR(50),
    currency        NVARCHAR(10)
);
GO

IF OBJECT_ID('bronze.account_mapping', 'U') IS NOT NULL DROP TABLE bronze.account_mapping;
CREATE TABLE bronze.account_mapping (
    AccountNumber   NVARCHAR(50),
    AccountName     NVARCHAR(100),
    PLLine          NVARCHAR(100),
    StatementType   NVARCHAR(50),
    SortOrder       NVARCHAR(20),
    Notes           NVARCHAR(500)
);
GO

IF OBJECT_ID('bronze.store', 'U') IS NOT NULL DROP TABLE bronze.store;
CREATE TABLE bronze.store (
    store_code  NVARCHAR(20),
    country     NVARCHAR(50),
    region      NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.storemaster', 'U') IS NOT NULL DROP TABLE bronze.storemaster;
CREATE TABLE bronze.storemaster (
    store_code  NVARCHAR(20),
    store_name  NVARCHAR(100),
    store_type  NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.gltransaction', 'U') IS NOT NULL DROP TABLE bronze.gltransaction;
CREATE TABLE bronze.gltransaction (
    transaction_id      NVARCHAR(20),
    transaction_date    NVARCHAR(20),
    store_code          NVARCHAR(20),
    account_number      NVARCHAR(20),
    amount_local        NVARCHAR(30),
    currency            NVARCHAR(10),
    document_number     NVARCHAR(50),
    description         NVARCHAR(500)
);
GO













USE DataWarehouse;
GO

BULK INSERT bronze.account
FROM 'C:\Users\HP\Downloads\dataset\data\account.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);

BULK INSERT bronze.account_mapping
FROM 'C:\Users\HP\Downloads\dataset\data\account_mapping.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);

BULK INSERT bronze.store
FROM 'C:\Users\HP\Downloads\dataset\data\store.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);

BULK INSERT bronze.storemaster
FROM 'C:\Users\HP\Downloads\dataset\data\store_master.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);

BULK INSERT bronze.gltransaction
FROM 'C:\Users\HP\Downloads\dataset\data\transaction.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);
GO


  