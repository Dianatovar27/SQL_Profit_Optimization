use warehouse chipmunk_wh;
use role training_role;
use database chipmunk_db;
CREATE schema SMARTDESK;

SELECT *
FROM ACCOUNTS;

SELECT *
FROM FORECASTS;

SELECT *
FROM SALES;

SELECT *
FROM ACCOUNTS;

--- 1. Sales and Profit Analysis by Product Category for Adabs Entertainment in 2020

SELECT 
    CATEGORY AS PRODUCT_CATEGORY,
    SUM(MAINTENANCE) AS TOTAL_MAINTENANCE,
    SUM(PRODUCT) AS TOTAL_PRODUCT,
    SUM(PARTS) AS TOTAL_PARTS,
    SUM(SUPPORT) AS TOTAL_SUPPORT,
    SUM(TOTAL) AS TOTAL_SALES,
    SUM(UNITS_SOLD) AS TOTAL_UNITS_SOLD,
    SUM(PROFIT) AS TOTAL_PROFIT
FROM SALES
WHERE ACCOUNT = 'Adabs Entertainment' AND YEAR = 2020
GROUP BY CATEGORY;

--- 2. Comparison of Sales, Units Sold, and Profit Among Industries in APAC and EMEA Regions

SELECT 
    A.C6 AS INDUSTRY,
    A.C5 AS COUNTRY, 
    A.C7 AS REGION,
    SUM(S.PRODUCT) AS TOTAL_PRODUCT, 
    SUM(S.UNITS_SOLD) AS TOTAL_UNITS_SOLD,
    SUM(S.PROFIT) AS TOTAL_PROFIT, 
    AVG(S.PROFIT) AS AVERAGE_PROFIT
FROM SALES AS S
INNER JOIN ACCOUNTS AS A
ON S.ACCOUNT = A.C1
WHERE REGION = 'APAC' OR REGION = 'EMEA'
GROUP BY INDUSTRY, COUNTRY, REGION
ORDER BY AVERAGE_PROFIT DESC;

-- 3. Profit Classification by Type of Company

-- SUBQUERY
SELECT DISTINCT ACCOUNT
FROM FORECASTS
WHERE FORECAST > 500000 AND YEAR = 2022;

-- MAIN QUERY
SELECT A.C6 AS INDUSTRY, SUM(S.PROFIT) AS TOTAL_PROFIT,
CASE WHEN TOTAL_PROFIT > 1000000 THEN 'High'
     ELSE 'Normal'
END AS "PROFIT_CATEGORY"
FROM SALES AS S
INNER JOIN ACCOUNTS AS A
ON S.ACCOUNT = A.C1
WHERE S.ACCOUNT IN (SELECT DISTINCT ACCOUNT
FROM FORECASTS
WHERE FORECAST > 500000 AND YEAR = 2022)
GROUP BY INDUSTRY
ORDER BY TOTAL_PROFIT DESC;

-- 4. Profit Comparison for Different Years

SELECT 
    COALESCE(S.CATEGORY, F.CATEGORY) AS CATEGORIES, 
    SUM(CASE WHEN S.QUARTER = '2020 Q1' THEN S.PROFIT ELSE 0 END) AS TOTAL_PROFIT_Q1_2020,
    SUM(CASE WHEN S.QUARTER = '2021 Q3' THEN S.PROFIT ELSE 0 END) AS TOTAL_PROFIT_Q3_2021,
    SUM(F.FORECAST) AS TOTAL_FORECAST,
    MAX(F.OPPORTUNITY_AGE) AS OLDEST_OPPORTUNITY, 
    MIN(F.OPPORTUNITY_AGE) AS NEWEST_OPPORTUNITY
FROM SALES AS S
LEFT JOIN FORECASTS AS F
ON S.CATEGORY = F.CATEGORY
WHERE S.QUARTER IN ('2020 Q1', '2021 Q3')
GROUP BY COALESCE(S.CATEGORY, F.CATEGORY)
ORDER BY TOTAL_FORECAST DESC;

-- 5. Calculation of Cumulative Profit by Quarter and Industry

SELECT DISTINCT 
       A.C6 AS INDUSTRY, 
       S.QUARTER,
       SUM(S.PROFIT) OVER (PARTITION BY A.C6 ORDER BY S.QUARTER) AS CUMULATIVE_PROFIT,
       SUM(F.FORECAST) OVER (PARTITION BY A.C6 ORDER BY S.QUARTER) AS CUMULATIVE_FORECAST,
       SUM(S.PROFIT) OVER (PARTITION BY A.C6) AS TOTAL_CUMULATIVE_PROFIT,
       ROUND(AVG(S.PROFIT) OVER (PARTITION BY A.C6), 2) AS AVERAGE_PROFIT
FROM SALES AS S
INNER JOIN ACCOUNTS AS A
    ON S.ACCOUNT = A.C1
INNER JOIN FORECASTS AS F 
    ON S.ACCOUNT = F.ACCOUNT 
   AND S.CATEGORY = F.CATEGORY
QUALIFY ROW_NUMBER() OVER (PARTITION BY A.C6, S.QUARTER ORDER BY S.QUARTER) = 1
ORDER BY TOTAL_CUMULATIVE_PROFIT DESC, INDUSTRY, S.QUARTER;

--- Identify the most profitable countries and industries 
CREATE OR REPLACE VIEW CountryIndustryProfit AS
SELECT 
       A.C5 AS COUNTRY,
       A.C6 AS INDUSTRY, 
       SUM(S.PROFIT) AS TOTAL_PROFIT
FROM ACCOUNTS AS A
INNER JOIN SALES AS S
ON A.C1 = S.ACCOUNT
GROUP BY A.C5, A.C6
ORDER BY TOTAL_PROFIT DESC;

--- Performance by Category and Type of Sale within Industries in the United States

CREATE OR REPLACE VIEW IndustryCategoryProfit_US AS
SELECT 
       A.C6 AS INDUSTRY, 
       S.CATEGORY AS CATEGORY,
       COALESCE(SUM(S.MAINTENANCE), 0) AS MAINTENANCE,
       COALESCE(SUM(S.PARTS), 0) AS PARTS,
       COALESCE(SUM(S.SUPPORT), 0) AS SUPPORT,
       COALESCE(SUM(S.PRODUCT), 0) AS PRODUCT,
       COALESCE(SUM(S.UNITS_SOLD), 0) AS UNITS_SOLD,
       COALESCE(SUM(S.PROFIT), 0) AS TOTAL_PROFIT
FROM ACCOUNTS AS A
INNER JOIN SALES AS S
ON A.C1 = S.ACCOUNT
WHERE A.C5 = 'United States' 
  AND A.C6 IN ('Finance', 'Retail', 'Law', 'Consulting', 'Entertainment and Media')
GROUP BY A.C6, S.CATEGORY
ORDER BY TOTAL_PROFIT DESC;

--- Profit Margin Per Unit Sold and Sales Volume by Industry and Category 

SELECT 
       A.C6 AS INDUSTRY, 
       S.CATEGORY AS CATEGORY,
       COALESCE(SUM(S.UNITS_SOLD), 0) AS UNITS_SOLD,
       COALESCE(SUM(S.PROFIT), 0) AS TOTAL_PROFIT,
       CASE 
           WHEN COALESCE(SUM(S.UNITS_SOLD), 0) > 10000 THEN 'HIGH VOLUME'
           ELSE 'LOW VOLUME'
       END AS VOLUME,
       ROUND(COALESCE(SUM(S.PROFIT), 0) / NULLIF(COALESCE(SUM(S.UNITS_SOLD), 0), 0), 2) AS PROFIT_MARGIN_PER_UNIT
FROM ACCOUNTS AS A
INNER JOIN SALES AS S
ON A.C1 = S.ACCOUNT
WHERE A.C5 = 'United States' 
  AND A.C6 IN ('Finance', 'Retail', 'Law', 'Consulting', 'Entertainment and Media')
  AND S.CATEGORY IN ('Break room', 'Electronics', 'Desks', 'Chairs')
GROUP BY A.C6, S.CATEGORY
ORDER BY PROFIT_MARGIN_PER_UNIT DESC;