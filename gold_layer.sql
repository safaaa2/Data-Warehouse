

use DataWarehouse
GO


CREATE TABLE gold.dimstore (
    store_key        INT IDENTITY(1,1) PRIMARY KEY,
    store_code       NVARCHAR(20),
    store_name       NVARCHAR(100),
    store_type       NVARCHAR(50),
    country          NVARCHAR(50),
    region           NVARCHAR(50)
);

INSERT INTO gold.dimstore 
SELECT
    s.store_code,
    sm.store_name,
    sm.store_type,
    s.country,
    s.region
FROM silver.store s
INNER JOIN silver.storemaster sm
    ON s.store_code = sm.store_code;


select * from gold.dimstore


--Creation des dimensions 

create table gold.dimaccount (
    account_key      INT IDENTITY(1,1) PRIMARY KEY,
    account_number   INT,
    account_name     NVARCHAR(100),
    account_type     NVARCHAR(50),
    pl_line          NVARCHAR(100),
    statement_type   NVARCHAR(50),
    sort_order       INT
);


INSERT INTO gold.dimaccount 
SELECT
    a.account_number,
    a.account_name ,
    a.account_type,
    am.PLLine,
    am.StatementType,
    am.SortOrder
FROM silver.account a
LEFT JOIN silver.account_mapping am
    ON a.account_name  = am.AccountName;


--Creation Fact_gl 

create table fact_gl (

    fact_key            INT IDENTITY(1,1) PRIMARY KEY,
    store_key           INT NOT NULL ,
    account_key         INT  NOT NULL ,
    transaction_date    DATE,
    store_code          NVARCHAR(20),
    account_number      NVARCHAR(20),
    amount_local        DECIMAL(18,2),
    currency            NVARCHAR(10),
    document_number     NVARCHAR(50),
    description         NVARCHAR(500),

   FOREIGN KEY (store_key)   REFERENCES gold.dimstore(store_key),
   FOREIGN KEY (account_key) REFERENCES gold.dimaccount(account_key)

)
--- ici on va effectuer l'insertion donnees 

insert into fact_gl 
select 
          
    st.store_key ,          
    a.account_key,         
    tr.transaction_date  ,  
    tr.store_code   ,       
    tr.account_number ,    
    tr.amount_local  ,      
    tr.currency  ,          
    tr.document_number ,    
    tr.description        

    from silver.gltransaction tr
    inner join gold.dimaccount a on 

    a.account_number  = tr.account_number

    inner join gold.dimstore st on 

    tr.store_code = st.store_code 


    select * from fact_gl




    -- Chercher les doublons dans dimaccount
SELECT account_number, COUNT(*) AS nb
FROM gold.dimaccount
GROUP BY account_number
HAVING COUNT(*) > 1;


-- 2. Nombre de lignes dans fact_gl
SELECT COUNT(*) AS nb_lignes FROM fact_gl;



-- ============================================
-- ETAPE 1 : Drop
-- ============================================
DROP TABLE IF EXISTS fact_gl;
DROP TABLE IF EXISTS gold.dimaccount;

-- ============================================
-- ETAPE 2 : Recréer dimaccount SANS doublons
-- ============================================
CREATE TABLE gold.dimaccount (
    account_key      INT IDENTITY(1,1) PRIMARY KEY,
    account_number   NVARCHAR(20),
    account_name     NVARCHAR(100),
    account_type     NVARCHAR(50),
    pl_line          NVARCHAR(100),
    statement_type   NVARCHAR(50),
    sort_order       INT
);

INSERT INTO gold.dimaccount
SELECT DISTINCT
    a.account_number,
    a.account_name,
    a.account_type,
    am.PLLine,
    am.StatementType,
    am.SortOrder
FROM silver.account a
LEFT JOIN silver.account_mapping am
    ON a.account_name = am.AccountName
WHERE am.PLLine IS NOT NULL;


-- ETAPE 3 : Vérifier 0 doublon

SELECT account_number, COUNT(*) AS nb
FROM gold.dimaccount
GROUP BY account_number
HAVING COUNT(*) > 1;







SELECT account_number, account_name, COUNT(*) AS nb
FROM silver.account
GROUP BY account_number, account_name
HAVING COUNT(*) > 1;





DROP TABLE IF EXISTS gold.dimaccount;

CREATE TABLE gold.dimaccount (
    account_key      INT IDENTITY(1,1) PRIMARY KEY,
    account_number   NVARCHAR(20),
    account_name     NVARCHAR(100),
    account_type     NVARCHAR(50),
    pl_line          NVARCHAR(100),
    statement_type   NVARCHAR(50),
    sort_order       INT
);

INSERT INTO gold.dimaccount
SELECT DISTINCT
    a.account_number,
    a.account_name,
    a.account_type,
    am.PLLine,
    am.StatementType,
    am.SortOrder
FROM (
    SELECT DISTINCT account_number, account_name, account_type
    FROM silver.account
) a
LEFT JOIN silver.account_mapping am
    ON a.account_name = am.AccountName



selecT * from gold.dimaccount

SELECT * FROM silver.account_mapping;

SELECT distinct account_number, account_name, account_type
FROM silver.account

SELECT DISTINCT tr.account_number
FROM silver.gltransaction tr
WHERE tr.account_number NOT IN (
    SELECT account_number FROM gold.dimaccount
);

-- Vérifier les stores orphelins
SELECT DISTINCT tr.store_code
FROM silver.gltransaction tr
WHERE tr.store_code NOT IN (
    SELECT store_code FROM gold.dimstore
);



CREATE TABLE gold.fact_gl (
    fact_key         INT IDENTITY(1,1) PRIMARY KEY,
    store_key        INT NOT NULL,
    account_key      INT NOT NULL,
    transaction_date DATE,
    store_code       NVARCHAR(20),
    account_number   NVARCHAR(20),
    amount_local     DECIMAL(18,2),
    currency         NVARCHAR(10),
    document_number  NVARCHAR(50),
    description      NVARCHAR(500),

    FOREIGN KEY (store_key)   REFERENCES gold.dimstore(store_key),
    FOREIGN KEY (account_key) REFERENCES gold.dimaccount(account_key)
);



INSERT INTO gold.fact_gl (
    store_key,
    account_key,
    transaction_date,
    store_code,
    account_number,
    amount_local,
    currency,
    document_number,
    description
)
SELECT
    st.store_key,
    a.account_key,
    tr.transaction_date,
    tr.store_code,
    tr.account_number,
    tr.amount_local,
    tr.currency,
    tr.document_number,
    tr.description
FROM silver.gltransaction tr
INNER JOIN gold.dimstore   st ON tr.store_code     = st.store_code
INNER JOIN gold.dimaccount  a ON tr.account_number = a.account_number;


-- Nombre de lignes chargées
SELECT COUNT(*) AS nb_lignes FROM gold.fact_gl;


-- Aperçu avec les libellés
SELECT TOP 10
    f.fact_key,
    f.transaction_date,
    s.store_name,
    s.country,
    a.account_name,
    a.pl_line,
    f.amount_local,
    f.currency
FROM gold.fact_gl f
INNER JOIN gold.dimstore   s ON f.store_key   = s.store_key
INNER JOIN gold.dimaccount a ON f.account_key = a.account_key;


-- Vérifie ça
SELECT account_number, COUNT(*) AS nb
FROM gold.dimaccount
GROUP BY account_number
HAVING COUNT(*) > 1;

SELECT *
FROM gold.dimaccount
WHERE account_number IN ('3000','4000','5000','5100','7000')
ORDER BY account_number;



DROP TABLE IF EXISTS gold.fact_gl;
DROP TABLE IF EXISTS gold.dimaccount;

-- ETAPE 2 : Recréer avec ROW_NUMBER pour garder 1 seule ligne par account_number
CREATE TABLE gold.dimaccount (
    account_key    INT IDENTITY(1,1) PRIMARY KEY,
    account_number NVARCHAR(20),
    account_name   NVARCHAR(100),
    account_type   NVARCHAR(50),
    pl_line        NVARCHAR(100),
    statement_type NVARCHAR(50),
    sort_order     INT
);

INSERT INTO gold.dimaccount
SELECT
    account_number,
    account_name,
    account_type,
    pl_line,
    statement_type,
    sort_order
FROM (
    SELECT
        a.account_number,
        a.account_name,
        a.account_type,
        am.PLLine        AS pl_line,
        am.StatementType AS statement_type,
        am.SortOrder     AS sort_order,
        ROW_NUMBER() OVER (
            PARTITION BY a.account_number 
            ORDER BY am.PLLine
        ) AS rn
    FROM silver.account a
    LEFT JOIN silver.account_mapping am
        ON a.account_name = am.AccountName
) sub
WHERE rn = 1;

-- ETAPE 3 : Vérifier 0 doublon
SELECT account_number, COUNT(*) AS nb
FROM gold.dimaccount
GROUP BY account_number
HAVING COUNT(*) > 1;



CREATE TABLE gold.fact_gl (
    fact_key         INT IDENTITY(1,1) PRIMARY KEY,
    store_key        INT NOT NULL,
    account_key      INT NOT NULL,
    transaction_date DATE,
    store_code       NVARCHAR(20),
    account_number   NVARCHAR(20),
    amount_local     DECIMAL(18,2),
    currency         NVARCHAR(10),
    document_number  NVARCHAR(50),
    description      NVARCHAR(500),
    FOREIGN KEY (store_key)   REFERENCES gold.dimstore(store_key),
    FOREIGN KEY (account_key) REFERENCES gold.dimaccount(account_key)
);

INSERT INTO gold.fact_gl (
    store_key, account_key, transaction_date,
    store_code, account_number, amount_local,
    currency, document_number, description
)
SELECT
    st.store_key,
    a.account_key,
    tr.transaction_date,
    tr.store_code,
    tr.account_number,
    tr.amount_local,
    tr.currency,
    tr.document_number,
    tr.description
FROM silver.gltransaction tr
INNER JOIN gold.dimstore   st ON tr.store_code     = st.store_code
INNER JOIN gold.dimaccount  a ON tr.account_number = a.account_number;

