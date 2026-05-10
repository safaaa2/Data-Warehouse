# 🏗️ Data Warehouse — NRG Retail Analytics

> Pipeline ETL complet : **CSV → Bronze → Silver → Gold → Power BI**  
> Architecture en couches pour l'analyse des performances financières et opérationnelles

---

## 📋 Table des matières

- [Contexte du projet](#-contexte-du-projet)
- [Architecture](#-architecture)
- [Structure des fichiers](#-structure-des-fichiers)
- [Sources de données](#-sources-de-données)
- [Couche Bronze](#-couche-bronze--ingestion)
- [Couche Silver](#-couche-silver--nettoyage)
- [Couche Gold](#-couche-gold--modèle-analytique)
- [Data Quality Checks](#-data-quality-checks)
- [Power BI](#-power-bi--reporting)
- [Outils utilisés](#-outils-utilisés)

---

## 🎯 Contexte du projet

Dans un contexte de **Data Engineering moderne**, ce projet simule le rôle d'un **Data Engineer / Data Analyst** chargé de concevoir un Data Warehouse complet basé sur une **architecture en couches (Medallion Architecture)**.

Le pipeline permet :
- L'ingestion de données brutes depuis des fichiers CSV (sources financières et opérationnelles)
- La structuration des données dans une couche **Bronze**
- Le nettoyage et la standardisation dans une couche **Silver**
- La modélisation analytique dans une couche **Gold** (Star Schema)
- La visualisation et le reporting via **Power BI**

---

## 🏛️ Architecture

```
CSV (source)
    │
    ▼
🥉 BRONZE — Ingestion brute (copie fidèle des fichiers source)
    │
    ▼
🥈 SILVER — Nettoyage & Standardisation (TRIM, UPPER, CAST, doublons)
    │
    ▼
🥇 GOLD — Star Schema (fact_gl + dimaccount + dimstore)
    │
    ▼
📊 POWER BI — Dashboards & Reporting
```

### Modèle en étoile (Star Schema)

```
       ┌─────────────────┐
       │  gold.dimaccount │
       │─────────────────│
       │ account_key (PK) │
       │ account_number   │
       │ account_name     │
       │ account_type     │
       │ pl_line          │
       │ statement_type   │
       │ sort_order       │
       └────────┬─────────┘
                │ 1
                │
  ┌─────────────▼──────────────┐        ┌─────────────────┐
  │       gold.fact_gl          │        │  gold.dimstore   │
  │────────────────────────────│        │─────────────────│
  │ fact_key (PK)               │  * 1  │ store_key (PK)  │
  │ account_key (FK) ──────────┤────────┤ store_code      │
  │ store_key (FK)              │        │ store_name      │
  │ account_number              │        │ store_type      │
  │ store_code                  │        │ country         │
  │ amount_local                │        │ region          │
  │ currency                    │        └─────────────────┘
  │ description                 │
  │ document_number             │
  │ transaction_date            │
  └─────────────────────────────┘
```

---

## 📁 Structure des fichiers

```
DataWarehouse/
│
├── 📂 data/                        # Fichiers sources CSV
│   ├── account.csv
│   ├── account_mapping.csv
│   ├── store.csv
│   ├── store_master.csv
│   └── transaction.csv
│
├── 📂 sql/
│   ├── 📂 bronze/
│   │   ├── 01_create_database.sql
│   │   ├── 02_create_schemas.sql
│   │   ├── 03_create_tables_bronze.sql
│   │   └── 04_bulk_insert.sql
│   │
│   ├── 📂 silver/
│   │   ├── 01_silver_account.sql
│   │   ├── 02_silver_store.sql
│   │   ├── 03_silver_storemaster.sql
│   │   ├── 04_silver_gltransaction.sql
│   │   └── 05_silver_account_mapping.sql
│   │
│   ├── 📂 gold/
│   │   ├── 01_gold_dimaccount.sql
│   │   ├── 02_gold_dimstore.sql
│   │   └── 03_gold_fact_gl.sql
│   │
│   └── 📂 quality/
│       ├── check_bronze.sql
│       ├── check_silver.sql
│       └── check_gold.sql
│
├── 📂 powerbi/
│   └── NRG_Retail_Dashboard.pbix
│
└── README.md
```

---

## 📂 Sources de données

| Fichier | Description | Lignes |
|---|---|---|
| `account.csv` | Référentiel des comptes comptables | 6 |
| `account_mapping.csv` | Mapping comptes → P&L (pl_line, statement_type) | 9 |
| `store.csv` | Référentiel des magasins (pays, région) | 7 |
| `store_master.csv` | Détails magasins (nom, type) | 7 |
| `transaction.csv` | Transactions GL (montants, dates) | **20 000** |

**Périmètre :** 7 magasins · Norvège & Suède · Devise NOK · 2025–2026

---

## 🥉 Couche Bronze — Ingestion

**Objectif :** Charger les fichiers CSV sans aucune transformation — copie fidèle des sources.

### Tables créées

| Table | Source |
|---|---|
| `bronze.account` | account.csv |
| `bronze.account_mapping` | account_mapping.csv |
| `bronze.store` | store.csv |
| `bronze.storemaster` | store_master.csv |
| `bronze.gltransaction` | transaction.csv |

### Exemple — BULK INSERT

```sql
BULK INSERT bronze.gltransaction
FROM 'C:\data\transaction.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '\n',
    FIRSTROW        = 2
);
```

---

## 🥈 Couche Silver — Nettoyage

**Objectif :** Nettoyer, standardiser et structurer les données pour analyse.

### Transformations appliquées

| Type | Transformation | Exemple |
|---|---|---|
| Technique | `TRIM()` sur tous les champs texte | `' Revenue '` → `'Revenue'` |
| Technique | `UPPER()` sur les codes | `'no001'` → `'NO001'` |
| Technique | `CAST()` des types de données | `VARCHAR` → `DATE` |
| Technique | Gestion des `NULL` | `NULL` → valeur par défaut |
| Standardisation | Correction des incohérences | `'P L'` → `'P&L'` |
| Doublons | `ROW_NUMBER()` pour dédupliquer | account_mapping (5100) |
| Métier | Jointure store + storemaster | Enrichissement des magasins |

### Exemple — Correction incohérence

```sql
UPDATE silver.account_mapping
SET StatementType = 'P&L'
WHERE StatementType = 'P L';
```

---

## 🥇 Couche Gold — Modèle analytique

**Objectif :** Construire un modèle de données prêt pour l'analyse (Star Schema).

### Dimensions

```sql
-- gold.dimaccount
SELECT
    ROW_NUMBER() OVER (ORDER BY a.account_number) AS account_key,
    a.account_number,
    a.account_name,
    a.account_type,
    m.PLLine       AS pl_line,
    m.StatementType AS statement_type,
    m.SortOrder    AS sort_order
FROM silver.account a
LEFT JOIN silver.account_mapping m
    ON a.account_number = m.AccountNumber;
```

```sql
-- gold.dimstore
SELECT
    ROW_NUMBER() OVER (ORDER BY s.store_code) AS store_key,
    s.store_code,
    sm.store_name,
    sm.store_type,
    s.country,
    s.region
FROM silver.store s
JOIN silver.storemaster sm
    ON s.store_code = sm.store_code;
```

### Table de faits

```sql
-- gold.fact_gl
SELECT
    ROW_NUMBER() OVER (ORDER BY t.transaction_date) AS fact_key,
    da.account_key,
    ds.store_key,
    t.account_number,
    t.store_code,
    t.amount_local,
    t.currency,
    t.description,
    t.document_number,
    t.transaction_date
FROM silver.gltransaction t
LEFT JOIN gold.dimaccount da ON t.account_number = da.account_number
LEFT JOIN gold.dimstore   ds ON t.store_code     = ds.store_code;
```

---

## 🧪 Data Quality Checks

### Résultats des contrôles

| Contrôle | Bronze | Silver | Gold | Statut |
|---|---|---|---|---|
| COUNT gltransaction | 20 000 | 20 000 | 20 000 | ✅ |
| Doublons account_mapping | — | 1 supprimé | — | ✅ |
| Correction 'P L' → 'P&L' | — | 1 corrigé | — | ✅ |
| Comptes non mappés (pl_line NULL) | — | 3 signalés | — | ⚠️ |
| Intégrité FK fact_gl → dimaccount | — | — | 0 orphelin | ✅ |
| Intégrité FK fact_gl → dimstore | — | — | 0 orphelin | ✅ |

### Exemples de requêtes de contrôle

```sql
-- COUNT Bronze vs Silver
SELECT 'Bronze' AS layer, COUNT(*) AS nb FROM bronze.gltransaction
UNION ALL
SELECT 'Silver', COUNT(*) FROM silver.gltransaction;

-- Vérification clés étrangères
SELECT COUNT(*) AS orphelins
FROM gold.fact_gl f
LEFT JOIN gold.dimaccount da ON f.account_key = da.account_key
WHERE da.account_key IS NULL;

-- Détection doublons
SELECT account_number, COUNT(*) AS nb
FROM silver.account_mapping
GROUP BY account_number
HAVING COUNT(*) > 1;
```

---

## 📊 Power BI — Reporting

### Pages du dashboard

| Page | Description | Visuels |
|---|---|---|
| **Accueil** | Navigation & KPIs globaux | Cartes, pipeline |
| **Vue globale P&L** | Compte de résultat complet | Waterfall, Matrice, Jauge |
| **Tendances** | Évolution temporelle | Courbes 2025 vs 2026 |
| **Magasins & Régions** | Performance par store | Barres, Carte géo, Donut |
| **Catégories** | Analyse par account_type | Anneau, Histogramme |

### Mesures DAX principales

```dax
Revenue = 
CALCULATE(SUM(fact_gl[amount_local]), dimaccount[account_number] = "3000")

Gross Profit = [Revenue] + [COGS]

GP Margin % = DIVIDE([Gross Profit], [Revenue], 0)

EBITDA = [Gross Profit] + [OpEx]

Net Income = [EBITDA] + [Financial]
```

### KPIs clés (FY 2025–2026)

| Indicateur | Valeur |
|---|---|
| Revenue total | 21.3M NOK |
| Gross Profit | 5.8M NOK |
| GP Margin | 27.3% |
| Nb transactions | 20 000 |
| Nb magasins | 7 |

---

## 🛠️ Outils utilisés

| Outil | Usage |
|---|---|
| **SQL Server Management Studio (SSMS)** | Création du Data Warehouse, requêtes T-SQL |
| **T-SQL** | ETL Bronze → Silver → Gold |
| **Power BI Desktop** | Modélisation, DAX, dashboards |
| **Power Query** | Nettoyage complémentaire des données |
| **CSV** | Fichiers sources bruts |

---

## 👤 Auteur

Projet réalisé dans le cadre de la formation **Data Analyst — INT Maroc**  
Période : 04/05/2026 → 08/05/2026
