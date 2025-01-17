-- Use specific Snowflake warehouse, role, and database
USE WAREHOUSE chipmunk_wh;
USE ROLE training_role;
USE DATABASE chipmunk_db;
CREATE SCHEMA SMARTDESK;

-- Use schema for querying
CHIPMUNK_DB.SMARTDESK;

-- Preview data from tables
SELECT * FROM ACCOUNTS;
SELECT * FROM FORECASTS;
SELECT * FROM SALES;

-- Adjustments made to the ACCOUNTS table due to column headers being loaded as c1, c2, etc.
SELECT * FROM ACCOUNTS
ORDER BY ACCOUNT_LEVEL ASC;

-- Remove duplicate rows and replace the ACCOUNTS table with the cleaned data
CREATE OR REPLACE TABLE temp_table AS
SELECT *
FROM ACCOUNTS
QUALIFY ROW_NUMBER() OVER (ORDER BY ACCOUNT_LEVEL ASC) > 1;

CREATE OR REPLACE TABLE ACCOUNTS AS
SELECT *
FROM temp_table;

DROP TABLE temp_table;

-- Confirm the changes
SELECT * FROM ACCOUNTS;

-- **1. Analysis of Sales and Profit by Product Category for Adabs Entertainment in 2020**
SELECT 
    CATEGORY AS CATEGORIA_PRODUCTO,
    SUM(MAINTENANCE) AS TOTAL_MANTENIMIENTO,
    SUM(PRODUCT) AS TOTAL_PRODUCTO,
    SUM(PARTS) AS TOTAL_PARTES,
    SUM(SUPPORT) AS TOTAL_SOPORTE,
    SUM(TOTAL) AS VENTAS_TOTALES,
    SUM(UNITS_SOLD) AS TOTAL_UNIDADES_VENDIDAS,
    SUM(PROFIT) AS BENEFICIO_TOTAL
FROM SALES
WHERE ACCOUNT = 'Adabs Entertainment' AND YEAR = 2020
GROUP BY CATEGORY;

-- **2. Comparison of Sales, Units Sold, and Profit by Industries in APAC and EMEA Regions**
SELECT 
    INDUSTRY,
    COUNTRY, 
    REGION,
    SUM(S.PRODUCT) AS TOTAL_PRODUCTO, 
    SUM(S.UNITS_SOLD) AS TOTAL_UNIDADES_VENDIDAS,
    SUM(S.PROFIT) AS BENEFICIO_TOTAL, 
    AVG(S.PROFIT) AS BENEFICIO_PROMEDIO
FROM SALES AS S
INNER JOIN ACCOUNTS AS A
ON S.ACCOUNT = A.ACCOUNT
WHERE REGION = 'APAC' OR REGION = 'EMEA'
GROUP BY INDUSTRY, COUNTRY, REGION
ORDER BY BENEFICIO_PROMEDIO DESC;

-- **3. Classification of Profit by Company Type**
-- Subquery to filter accounts with forecasts above $500,000 in 2022
SELECT DISTINCT ACCOUNT
FROM FORECASTS
WHERE FORECAST > 500000 AND YEAR= 2022;

-- Main Query: Summarize profit and classify as 'High' or 'Normal'
SELECT INDUSTRY, SUM(S.PROFIT) AS BENEFICIO_TOTAL,
CASE WHEN BENEFICIO_TOTAL > 1000000 THEN 'Alto'
     ELSE 'Normal'
END AS "CATEGORIA_DE_BENEFICIO"
FROM SALES AS S
INNER JOIN ACCOUNTS AS A
ON S.ACCOUNT = A.ACCOUNT
WHERE S.ACCOUNT IN (SELECT DISTINCT ACCOUNT
FROM FORECASTS
WHERE FORECAST > 500000 AND YEAR= 2022)
GROUP BY INDUSTRY
ORDER BY BENEFICIO_TOTAL DESC;

-- **4. Comparison of Profits Across Different Years**
SELECT 
    COALESCE(S.CATEGORY, F.CATEGORY) AS CATEGORIAS,
    SUM(CASE WHEN S.QUARTER = '2020 Q1' THEN S.PROFIT ELSE 0 END) AS BENEFICIO_TOTAL_Q1_2020,
    SUM(CASE WHEN S.QUARTER = '2021 Q3' THEN S.PROFIT ELSE 0 END) AS BENEFICIO_TOTAL_Q3_2021,
    SUM(CASE WHEN F.YEAR = 2022 THEN F.FORECAST ELSE 0 END) AS FORECAST_TOTAL_2022,
    MAX(F.OPPORTUNITY_AGE) AS OLD_OPPORTUNITY,
    MIN(F.OPPORTUNITY_AGE) AS YOUNG_OPPORTUNITY
FROM SALES AS S
FULL OUTER JOIN FORECASTS AS F
ON S.CATEGORY = F.CATEGORY AND S.YEAR = F.YEAR
WHERE S.QUARTER IN ('2020 Q1', '2021 Q3') OR F.YEAR = 2022
GROUP BY COALESCE(S.CATEGORY, F.CATEGORY)
ORDER BY FORECAST_TOTAL_2022 DESC;

-- **5. Calculation of Cumulative Profit by Quarter and Industry**
SELECT Industry,
       QUARTER,
       SUM(PROFIT) AS Beneficio,
       SUM(Forecast) AS Pronostico,
       ROUND(AVG(Beneficio) OVER (PARTITION BY INDUSTRY ORDER BY QUARTER ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS Beneficio_Promedio,
       SUM(SUM(PROFIT)) OVER (PARTITION BY INDUSTRY ORDER BY QUARTER) AS Beneficio_Acumulado,
       SUM(SUM(FORECAST)) OVER (PARTITION BY INDUSTRY) AS Pronostico_Acumulado_total
FROM SALES S
JOIN ACCOUNTS A ON S.ACCOUNT = A.ACCOUNT
JOIN FORECASTS F ON F.ACCOUNT = S.ACCOUNT
GROUP BY INDUSTRY, QUARTER
ORDER BY INDUSTRY, QUARTER;

-- Option with granular subquery for better performance
WITH cs AS (
    SELECT Industry,
           QUARTER,
           SUM(PROFIT) AS Beneficio,
           SUM(Forecast) AS Pronostico
    FROM SALES S
    JOIN ACCOUNTS A ON S.ACCOUNT = A.ACCOUNT
    JOIN FORECASTS F ON F.ACCOUNT = S.ACCOUNT
    GROUP BY INDUSTRY, QUARTER
)
SELECT Industry,
       QUARTER,
       Beneficio,
       Pronostico,
       ROUND(AVG(Beneficio) OVER (PARTITION BY INDUSTRY ORDER BY QUARTER ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS Beneficio_Promedio,
       SUM(Beneficio) OVER (PARTITION BY INDUSTRY ORDER BY QUARTER) AS Beneficio_Acumulado,
       SUM(Pronostico) OVER (PARTITION BY INDUSTRY ORDER BY QUARTER) AS Pronostico_Acumulado
FROM cs
ORDER BY Industry, QUARTER;

-- **Case Study: Custom Analysis**
-- Discover the most profitable countries and industries
CREATE OR REPLACE VIEW CountryIndustryProfit AS
SELECT 
       COUNTRY,
       INDUSTRY, 
       SUM(S.PROFIT) AS PROFIT_TOTAL
FROM ACCOUNTS AS A
INNER JOIN SALES AS S
ON A.ACCOUNT = S.ACCOUNT
GROUP BY A.COUNTRY, A.INDUSTRY
ORDER BY PROFIT_TOTAL DESC;

-- Performance by category and type of sale in the U.S.
CREATE OR REPLACE VIEW IndustryCategoryProfit_US AS
SELECT 
       INDUSTRY, 
       S.CATEGORY AS CATEGORIA,
       COALESCE(SUM(S.MAINTENANCE), 0) AS MANTENIMIENTO,
       COALESCE(SUM(S.PARTS), 0) AS PARTES,
       COALESCE(SUM(S.SUPPORT), 0) AS SOPORTE,
       COALESCE(SUM(S.PRODUCT), 0) AS PRODUCTO,
       COALESCE(SUM(S.UNITS_SOLD), 0) AS UNIDADES_VENDIDAS,
       COALESCE(SUM(S.PROFIT), 0) AS PROFIT_TOTAL
FROM ACCOUNTS AS A
INNER JOIN SALES AS S
ON A.ACCOUNT = S.ACCOUNT
WHERE A.COUNTRY = 'United States' 
  AND A.INDUSTRY IN ('Finance', 'Retail', 'Law', 'Consulting', 'Entertainment and Media')
GROUP BY A.INDUSTRY, S.CATEGORY
ORDER BY PROFIT_TOTAL DESC;

-- Profit margin per unit sold and sales volume by industry and category
SELECT 
       INDUSTRY, 
       S.CATEGORY AS CATEGORIA,
       COALESCE(SUM(S.UNITS_SOLD), 0) AS UNIDADES_VENDIDAS,
       COALESCE(SUM(S.PROFIT), 0) AS PROFIT_TOTAL,
       CASE 
           WHEN COALESCE(SUM(S.UNITS_SOLD), 0) > 10000 THEN 'ALTO VOLUMEN'
           ELSE 'BAJO VOLUMEN'
       END AS VOLUMEN,
       ROUND(COALESCE(SUM(S.PROFIT), 0) / NULLIF(COALESCE(SUM(S.UNITS_SOLD), 0), 0), 2) AS MARGEN_POR_UNIDAD
FROM ACCOUNTS AS A
INNER JOIN SALES AS S
ON A.ACCOUNT = S.ACCOUNT
WHERE A.COUNTRY = 'United States' 
  AND A.INDUSTRY IN ('Finance', 'Retail', 'Law', 'Consulting', 'Entertainment and Media')
  AND S.CATEGORY IN ('Break room', 'Electronics', 'Desks', 'Chairs')
GROUP BY A.INDUSTRY, S.CATEGORY
ORDER BY MARGEN_POR_UNIDAD DESC;
