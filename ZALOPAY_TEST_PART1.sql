----------------------------------------
-- ZaloPay Data Analyst – Home Test
-- PART I: Programming (SQL Server / T-SQL)
----------------------------------------

-- QUESTION 1: The first 2 appID user payments and the date that users used those services? 

WITH ranked AS (
    SELECT
        userID,
        appID,
        CAST(TransactionDate AS DATE) AS txn_date,
        ROW_NUMBER() OVER (
            PARTITION BY userID
            ORDER BY TransactionDate, transID    
        ) AS rn
    FROM fact
)
SELECT
    userID,
    MAX(CASE WHEN rn = 1 THEN appID    END) AS FirstAppID,
    MAX(CASE WHEN rn = 1 THEN txn_date END) AS FirstAppIDDate,
	MAX(CASE WHEN rn = 2 THEN appID    END) AS SecondAppID,
    MAX(CASE WHEN rn = 2 THEN txn_date END) AS SecondAppIDDate
FROM ranked
WHERE rn <= 2
GROUP BY userID
ORDER BY userID;
	
-- QUESTION 2:  The last storeID user payments and the date that users used that service?
WITH ranked AS (
    SELECT
        f.userID,
        f.storeID,
        CAST(f.TransactionDate AS DATE) AS txn_date,
        ROW_NUMBER() OVER (
            PARTITION BY f.userID
            ORDER BY CAST(f.[TransactionDate] as date) DESC    
        ) AS rn
    FROM fact f
)
SELECT
    userID,
    storeID  AS LastStoreID,
    txn_date AS LastStoreDate
FROM ranked
WHERE rn = 1
ORDER BY userID;
 
 -- QUESTION 3: How many distinct merchantID & channels that users pay for?

SELECT
    f.userID,
    COUNT(DISTINCT m.merchantID) AS DistinctMerchantID,
    COUNT(DISTINCT f.Channel)    AS DistinctChannel
FROM fact f
LEFT JOIN dim_merchant m ON f.appID = m.appid
GROUP BY f.userID
ORDER BY f.userID;

-- QUESTION 4: How much SaleVolume did each users spend in the last 30 days?
SELECT
    f.userID,
    SUM(f.SalesAmount) AS SaleVolume_Last30Days
FROM fact f
WHERE CAST(f.TransactionDate AS DATE) > DATEADD(DAY, -30, (SELECT MAX(CAST(TransactionDate AS DATE)) FROM fact))
GROUP BY f.userID
ORDER BY f.userID;

-- QUESTION 1–4 TỔNG HỢP: Gộp tất cả thành 1 bảng per-user (1 query duy nhất)
WITH
max_date AS (
    SELECT MAX(CAST(TransactionDate AS DATE)) AS md FROM fact
),
ranked_asc AS (
    SELECT
        userID, appID, storeID, TransactionDate, transID,
        ROW_NUMBER() OVER (PARTITION BY userID ORDER BY TransactionDate, transID) AS rn_asc
    FROM fact
),
ranked_desc AS (
    SELECT
        userID, storeID, TransactionDate,
        ROW_NUMBER() OVER (PARTITION BY userID ORDER BY TransactionDate DESC, transID DESC) AS rn_desc
    FROM fact
),
q1 AS (
    SELECT
        userID,
        MAX(CASE WHEN rn_asc = 1 THEN appID                           END) AS FirstAppID,
        MAX(CASE WHEN rn_asc = 2 THEN appID                           END) AS SecondAppID,
        MAX(CASE WHEN rn_asc = 1 THEN CAST(TransactionDate AS DATE)   END) AS FirstAppIDDate,
        MAX(CASE WHEN rn_asc = 2 THEN CAST(TransactionDate AS DATE)   END) AS SecondAppIDDate
    FROM ranked_asc
    WHERE rn_asc <= 2
    GROUP BY userID
),
q2 AS (
    SELECT
        userID,
        storeID                          AS LastStoreID,
        CAST(TransactionDate AS DATE)    AS LastStoreDate
    FROM ranked_desc
    WHERE rn_desc = 1
),
q3 AS (
    SELECT
        f.userID,
        COUNT(DISTINCT m.merchantID) AS DistinctMerchantID,
        COUNT(DISTINCT f.Channel)    AS DistinctChannel
    FROM fact f
    LEFT JOIN dim_merchant m ON f.appID = m.appid
    GROUP BY f.userID
),
q4 AS (
    SELECT
        f.userID,
        SUM(f.SalesAmount) AS SaleVolume_Last30Days
    FROM fact f
    CROSS JOIN max_date
    WHERE CAST(f.TransactionDate AS DATE) > DATEADD(DAY, -30, md)
    GROUP BY f.userID
)
SELECT
    q1.userID,
    q1.FirstAppID,
    q1.SecondAppID,
    q1.FirstAppIDDate,
    q1.SecondAppIDDate,
    q2.LastStoreID,
    q2.LastStoreDate,
    q3.DistinctMerchantID,
    q3.DistinctChannel,
    COALESCE(q4.SaleVolume_Last30Days, 0) AS SaleVolume_Last30Days
FROM q1
LEFT JOIN q2 ON q1.userID = q2.userID
LEFT JOIN q3 ON q1.userID = q3.userID
LEFT JOIN q4 ON q1.userID = q4.userID
ORDER BY q1.userID;

-- QUESTION 5: Find the merchantName that has the highest applied voucher transactions.
 
SELECT TOP 1
    m.merchantName,
    COUNT(*) AS VoucherTransactions
FROM fact f
LEFT JOIN dim_merchant m ON f.appID = m.appid
WHERE f.VoucherStatus = 1
GROUP BY m.merchantName
ORDER BY VoucherTransactions DESC;

-- QUESTION 6: Find the Province that has the highest sale volume in the last 45 days.
 
WITH max_date AS (
    SELECT MAX(CAST(TransactionDate AS DATE)) AS md FROM fact
)
SELECT TOP 1
    s.Province,
    SUM(CAST(f.SalesAmount AS BIGINT)) AS TotalSaleVolume
FROM fact f
LEFT JOIN dim_store s ON f.storeID = s.storeID
CROSS JOIN max_date
WHERE CAST(f.TransactionDate AS DATE) > DATEADD(DAY, -45, md)
GROUP BY s.Province
ORDER BY TotalSaleVolume DESC;
