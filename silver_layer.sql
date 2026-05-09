
USE DataWarehouse;
GO
-- Table : silver.account
IF OBJECT_ID('silver.account', 'U') IS NOT NULL DROP TABLE silver.account;
CREATE TABLE silver.account (
    account_number  NVARCHAR(50),
    account_name    NVARCHAR(100),
    account_type    NVARCHAR(50),
    currency        NVARCHAR(10)
);
GO

-- Table : silver.account_mapping
IF OBJECT_ID('silver.account_mapping', 'U') IS NOT NULL DROP TABLE silver.account_mapping;
CREATE TABLE silver.account_mapping (
    AccountNumber   NVARCHAR(50),
    AccountName     NVARCHAR(100),
    PLLine          NVARCHAR(100),
    StatementType   NVARCHAR(50),
    SortOrder       DECIMAL(10,2),
    Notes           NVARCHAR(500)
);
GO

-- Table : silver.store
IF OBJECT_ID('silver.store', 'U') IS NOT NULL DROP TABLE silver.store;
CREATE TABLE silver.store (
    store_code  NVARCHAR(20),
    country     NVARCHAR(50),
    region      NVARCHAR(50)
);
GO

-- Table : silver.storemaster
IF OBJECT_ID('silver.storemaster', 'U') IS NOT NULL DROP TABLE silver.storemaster;
CREATE TABLE silver.storemaster (
    store_code  NVARCHAR(20),
    store_name  NVARCHAR(100),
    store_type  NVARCHAR(50)
);
GO

-- Table : silver.gltransaction
IF OBJECT_ID('silver.gltransaction', 'U') IS NOT NULL DROP TABLE silver.gltransaction;
CREATE TABLE silver.gltransaction (
    transaction_id      INT,
    transaction_date    DATE,
    store_code          NVARCHAR(20),
    account_number      NVARCHAR(20),
    amount_local        DECIMAL(18,2),
    currency            NVARCHAR(10),
    document_number     NVARCHAR(50),
    description         NVARCHAR(500)
);
GO
-- silver.account
-- Nettoyage : TRIM des espaces, UPPER sur currency
-- -------------------------------------------------------
INSERT INTO silver.account (
    account_number,
    account_name,
    account_type,
    currency
)
SELECT
    TRIM(account_number)                AS account_number,
    TRIM(account_name)                  AS account_name,
    TRIM(account_type)                  AS account_type,
    UPPER(TRIM(currency))               AS currency
FROM bronze.account
WHERE account_number IS NOT NULL        -- exclure les lignes vides
  AND TRIM(account_number) != '';
GO


-- silver.account_mapping
-- Nettoyage :
--   - Suppression des doublons (account 5100 apparaît 2x)
--   - Correction "P L" → "P&L"
--   - TRIM partout
--   - NULL remplacé par 'Non défini'
--   - SortOrder converti en DECIMAL
-- -------------------------------------------------------
INSERT INTO silver.account_mapping (
    AccountNumber,
    AccountName,
    PLLine,
    StatementType,
    SortOrder,
    Notes
)
SELECT
    TRIM(AccountNumber)                                         AS AccountNumber,
    TRIM(AccountName)                                           AS AccountName,

    -- Correction de l'incohérence "P L" → "P&L"
    CASE
        WHEN TRIM(PLLine) = ''   THEN 'Non défini'
        WHEN PLLine IS NULL      THEN 'Non défini'
        ELSE TRIM(PLLine)
    END                                                         AS PLLine,

    -- Correction "P L" → "P&L" dans StatementType
    CASE
        WHEN TRIM(StatementType) = 'P L'  THEN 'P&L'
        WHEN TRIM(StatementType) = ''     THEN 'Non défini'
        WHEN StatementType IS NULL        THEN 'Non défini'
        ELSE TRIM(StatementType)
    END                                                         AS StatementType,

    -- Conversion SortOrder en nombre
    CASE
        WHEN TRIM(SortOrder) = '' OR SortOrder IS NULL
        THEN NULL
        ELSE CAST(SortOrder AS DECIMAL(10,2))
    END                                                         AS SortOrder,

    -- Remplacement des Notes vides
    CASE
        WHEN TRIM(ISNULL(Notes,'')) = '' THEN 'Aucune note'
        ELSE TRIM(Notes)
    END                                                         AS Notes

FROM (
    -- Suppression des doublons : on garde la 1ère occurrence par AccountNumber + PLLine
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY AccountNumber, PLLine
            ORDER BY SortOrder
        ) AS rn
    FROM bronze.account_mapping
    WHERE AccountNumber IS NOT NULL
      AND TRIM(AccountNumber) != ''
) AS dedup
WHERE rn = 1;
GO

-- -------------------------------------------------------
-- silver.store
-- Nettoyage : TRIM, UPPER sur store_code
-- -------------------------------------------------------
INSERT INTO silver.store (
    store_code,
    country,
    region
)
SELECT
    UPPER(TRIM(store_code))     AS store_code,
    TRIM(country)               AS country,
    TRIM(region)                AS region
FROM bronze.store
WHERE store_code IS NOT NULL
  AND TRIM(store_code) != '';
GO

-- -------------------------------------------------------
-- silver.storemaster
-- Nettoyage : TRIM, UPPER sur store_code
-- -------------------------------------------------------
INSERT INTO silver.storemaster (
    store_code,
    store_name,
    store_type
)
SELECT
    UPPER(TRIM(store_code))     AS store_code,
    TRIM(store_name)            AS store_name,
    TRIM(store_type)            AS store_type
FROM bronze.storemaster
WHERE store_code IS NOT NULL
  AND TRIM(store_code) != '';
GO


-- Nettoyage et chargement : bronze → silver

INSERT INTO silver.gltransaction

SELECT
    CAST(TRIM(transaction_id)   AS INT)           AS transaction_id,
    CAST(TRIM(transaction_date) AS DATE)          AS transaction_date,
    UPPER(TRIM(store_code))                       AS store_code,
    TRIM(account_number)                           AS account_number,
    CAST(TRIM(amount_local) AS DECIMAL(18,2))    AS amount_local,
    UPPER(TRIM(currency))                           AS currency,
    TRIM(document_number)                          AS document_number,
    TRIM(description)                               AS description

FROM bronze.gltransaction

WHERE
    transaction_id   IS NOT NULL
    AND transaction_date IS NOT NULL
    AND TRIM(transaction_id)   != ''
    AND TRIM(transaction_date) != ''
    AND TRIM(amount_local)     != ''
    AND ISNUMERIC(amount_local) = 1;



    ---lets test

SELECT 'bronze.account'         AS couche, COUNT(*) AS nb_lignes FROM bronze.account


---Les 5 Tops 
SELECT TOP 5
    transaction_id,
    transaction_date,
    amount_local,
    currency
FROM silver.gltransaction;
GO


-- Vérifier la correction "P&L" dans account_mapping
SELECT AccountNumber, AccountName, PLLine, StatementType, SortOrder
FROM silver.account_mapping
ORDER BY AccountNumber;
GO

SELECT TOP 3 * FROM silver.gltransaction;

SELECT TOP 3 * FROM silver.store;

SELECT TOP 3 * FROM silver.account;


--voir les doublons 
SELECT 
    transaction_date,
    store_code,
    account_number,
    amount_local,
    document_number,
    COUNT(*) AS nb
FROM silver.gltransaction
GROUP BY 
    transaction_date, store_code, 
    account_number, amount_local, document_number
HAVING COUNT(*) > 1;
