/**********************************************************
 * 專案名稱：夏季奧運數據進階分析 (SQL Window Functions)
 * 核心技術：CTE, Ranking, Lead/Lag, Sliding Windows, Crosstab
 **********************************************************/

-- ==========================================================
-- 第一部分：競爭力排名分析 (Ranking & Partitioning)
-- 目的：分析運動員與國家的競爭力排名
-- ==========================================================

WITH Athlete_Medals AS (
    SELECT 
        Country, 
        Athlete, 
        COUNT(*) AS Medals
    FROM Summer_Medals
    WHERE Year >= 2000
    GROUP BY Country, Athlete
    HAVING COUNT(*) > 1
)
SELECT 
    Country, 
    Athlete, 
    Medals,
    -- 使用 DENSE_RANK 處理同分排名，確保排名不跳號
    DENSE_RANK() OVER (PARTITION BY Country ORDER BY Medals DESC) AS Rank_In_Country
FROM Athlete_Medals
ORDER BY Country ASC, Rank_In_Country ASC;


-- ==========================================================
-- 第二部分：時序趨勢與衛冕分析 (Time Series & Lag/Lead)
-- 目的：追蹤各國在特定項目是否成功衛冕金牌，分析金牌傳承
-- ==========================================================

WITH Gold_Champions AS (
    SELECT DISTINCT
        Gender, Year, Event, Country
    FROM Summer_Medals
    WHERE Medal = 'Gold' 
      AND Discipline = 'Athletics' -- 以田徑項目為例
      AND Event IN ('100M', '10000M')
)
SELECT 
    Gender, Year, Event,
    Country AS Current_Champion,
    -- 使用 LAG 抓取上一屆金牌國，分析「金牌傳承」
    LAG(Country) OVER (PARTITION BY Gender, Event ORDER BY Year ASC) AS Previous_Champion
FROM Gold_Champions
ORDER BY Event ASC, Gender ASC, Year ASC;


-- ==========================================================
-- 第三部分：滑動視窗與累計成長 (Sliding Windows & Aggregations)
-- 目的：計算三屆奧運的移動平均獎牌數，常用於分析成長動能
-- ==========================================================

WITH Country_Medals AS (
    SELECT 
        Year, Country, COUNT(*) AS Medals
    FROM Summer_Medals
    WHERE Medal = 'Gold'
    GROUP BY Year, Country
)
SELECT 
    Year, Country, Medals,
    -- 計算各國「三屆移動平均獎牌數」(3-game Moving Average)
    -- 此技巧可平滑數據波動，展現長期趨勢
    AVG(Medals) OVER (
        PARTITION BY Country 
        ORDER BY Year ASC 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS Medals_MA_3_Years,
    -- 計算各國歷年「累計金牌總數」
    SUM(Medals) OVER (
        PARTITION BY Country 
        ORDER BY Year ASC
    ) AS Cumulative_Gold_Total
FROM Country_Medals
WHERE Country IN ('CHN', 'USA', 'JPN')
ORDER BY Country, Year;


-- ==========================================================
-- 第四部分：報表層級彙總 (Reporting - ROLLUP & CUBE)
-- 目的：生成包含「總計」與「分計」的高階商業報表
-- ==========================================================

SELECT 
    COALESCE(Country, 'TOTAL') AS Country,
    COALESCE(Gender, 'All Genders') AS Gender,
    COUNT(*) AS Gold_Awards
FROM Summer_Medals
WHERE Year = 2012 AND Medal = 'Gold'
  AND Country IN ('USA', 'GBR', 'CHN')
-- 使用 ROLLUP 自動生成國家與性別的多層次統計
GROUP BY ROLLUP(Country, Gender)
ORDER BY Country, Gender;
