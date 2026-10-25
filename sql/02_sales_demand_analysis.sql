-- ============================================================
-- PROJECT: Sales Forecasting & Demand Prediction Analysis
-- FILE: 02_sales_demand_analysis.sql
-- DATABASE: sales_forecasting_db
-- TABLE: historical_sales
-- ============================================================
--
-- PURPOSE:
-- Analyze historical unit sales, demand patterns,
-- growth trends, store performance, item performance,
-- seasonality, and demand variability.
--
-- DATASET:
-- 913,000 sales records
-- 10 stores, 50 items
-- Period: 2013-01-01 to 2017-12-31
--
-- NOTE:
-- Sales represent units sold, not monetary revenue.
-- ============================================================

-- ============================================================
-- ANALYSIS 01: YEARLY SALES GROWTH
-- ============================================================
-- Objective:
-- Calculate annual units sold and year-over-year growth.
--
-- Business Use:
-- Identify demand growth trends across years.
-- ============================================================

WITH yearly_sales AS (
    SELECT
        "Year" AS sales_year,
        SUM(sales) AS total_units_sold
    FROM historical_sales
    GROUP BY "Year"
),
yearly_growth AS (
    SELECT
        sales_year,
        total_units_sold,
        LAG(total_units_sold) OVER (
            ORDER BY sales_year
        ) AS previous_year_units
    FROM yearly_sales
)
SELECT
    sales_year,
    total_units_sold,
    previous_year_units,
    ROUND(
        (total_units_sold - previous_year_units) * 100.0
        / NULLIF(previous_year_units, 0),
        2
    ) AS yoy_growth_percent
FROM yearly_growth
ORDER BY sales_year;


-- ============================================================
-- ANALYSIS 02: MONTHLY SALES TREND (2017)
-- ============================================================
-- Objective:
-- Analyze monthly sales volume and average units sold.
--
-- Business Use:
-- Identify peak-demand and low-demand months.
-- ============================================================

SELECT
    "Year" AS sales_year,
    "Month" AS sales_month,
    TO_CHAR(
        MAKE_DATE("Year", "Month", 1),
        'Mon'
    ) AS month_name,
    SUM(sales) AS total_units_sold,
    COUNT(*) AS total_records,
    ROUND(AVG(sales), 2) AS avg_units_per_record
FROM historical_sales
WHERE "Year" = 2017
GROUP BY "Year", "Month"
ORDER BY sales_year, sales_month;


-- ============================================================
-- ANALYSIS 03: MONTH-OVER-MONTH SALES GROWTH (2017)
-- ============================================================
-- Objective:
-- Calculate monthly demand growth or decline.
--
-- Business Use:
-- Identify months with significant demand changes.
-- ============================================================

WITH monthly_sales AS (
    SELECT
        "Month" AS sales_month,
        SUM(sales) AS total_units_sold
    FROM historical_sales
    WHERE "Year" = 2017
    GROUP BY "Month"
),
monthly_growth AS (
    SELECT
        sales_month,
        total_units_sold,
        LAG(total_units_sold) OVER (
            ORDER BY sales_month
        ) AS previous_month_units
    FROM monthly_sales
)
SELECT
    sales_month,
    TO_CHAR(
        MAKE_DATE(2017, sales_month, 1),
        'Mon'
    ) AS month_name,
    total_units_sold,
    previous_month_units,
    ROUND(
        (total_units_sold - previous_month_units) * 100.0
        / NULLIF(previous_month_units, 0),
        2
    ) AS mom_growth_percent
FROM monthly_growth
ORDER BY sales_month;


-- ============================================================
-- ANALYSIS 04: STORE-WISE SALES PERFORMANCE
-- ============================================================
-- Objective:
-- Compare total units sold across stores.
--
-- Business Use:
-- Identify top-performing stores and their contribution
-- to overall demand.
-- ============================================================

WITH store_sales AS (
    SELECT
        store AS store_id,
        SUM(sales) AS total_units_sold,
        COUNT(*) AS total_records,
        ROUND(AVG(sales), 2) AS avg_units_per_record
    FROM historical_sales
    GROUP BY store
)
SELECT
    store_id,
    total_units_sold,
    total_records,
    avg_units_per_record,
    ROUND(
        total_units_sold * 100.0
        / SUM(total_units_sold) OVER (),
        2
    ) AS contribution_percent
FROM store_sales
ORDER BY total_units_sold DESC;


-- ============================================================
-- ANALYSIS 05: ITEM-WISE DEMAND ANALYSIS
-- ============================================================
-- Objective:
-- Identify the top 10 highest-demand items.
--
-- Business Use:
-- Support product prioritization and inventory planning.
-- ============================================================

WITH item_sales AS (
    SELECT
        item AS item_id,
        SUM(sales) AS total_units_sold,
        COUNT(*) AS total_records,
        ROUND(AVG(sales), 2) AS avg_units_per_record
    FROM historical_sales
    GROUP BY item
)
SELECT
    item_id,
    total_units_sold,
    total_records,
    avg_units_per_record,
    ROUND(
        total_units_sold * 100.0
        / SUM(total_units_sold) OVER (),
        2
    ) AS contribution_percent
FROM item_sales
ORDER BY total_units_sold DESC
LIMIT 10;


-- ============================================================
-- ANALYSIS 06: WEEKDAY VS WEEKEND DEMAND
-- ============================================================
-- Objective:
-- Compare sales demand on weekdays and weekends.
--
-- Business Use:
-- Identify weekly demand patterns for inventory planning.
-- ============================================================

WITH daily_sales AS (
    SELECT
        date,
        CASE
            WHEN "Is_Weekend" = 1 THEN 'Weekend'
            ELSE 'Weekday'
        END AS day_type,
        SUM(sales) AS daily_units
    FROM historical_sales
    GROUP BY date, "Is_Weekend"
),
demand_summary AS (
    SELECT
        day_type,
        COUNT(*) AS total_days,
        SUM(daily_units) AS total_units_sold,
        ROUND(AVG(daily_units), 2) AS avg_daily_units
    FROM daily_sales
    GROUP BY day_type
)
SELECT
    day_type,
    total_days,
    total_units_sold,
    avg_daily_units
FROM demand_summary
ORDER BY day_type;


-- ============================================================
-- ANALYSIS 07: DAY-OF-WEEK DEMAND ANALYSIS
-- ============================================================
-- Objective:
-- Compare daily sales demand from Monday to Sunday.
--
-- Business Use:
-- Identify peak-demand weekdays for inventory planning
-- and demand forecasting.
-- ============================================================

WITH daily_sales AS (
    SELECT
        date,
        EXTRACT(ISODOW FROM date)::INTEGER AS day_number,
        TO_CHAR(date, 'FMDay') AS day_name,
        SUM(sales) AS daily_units
    FROM historical_sales
    GROUP BY date
)
SELECT
    day_number,
    day_name,
    COUNT(*) AS total_days,
    SUM(daily_units) AS total_units_sold,
    ROUND(AVG(daily_units), 2) AS avg_daily_units
FROM daily_sales
GROUP BY day_number, day_name
ORDER BY day_number;


-- ============================================================
-- ANALYSIS 08: SEASONAL DEMAND ANALYSIS
-- ============================================================
-- Objective:
-- Identify recurring monthly demand patterns across
-- the complete historical dataset (2013-2017).
--
-- Business Use:
-- Support seasonal inventory planning and forecasting.
-- ============================================================

WITH daily_sales AS (
    SELECT
        date,
        EXTRACT(MONTH FROM date)::INTEGER AS sales_month,
        SUM(sales) AS daily_units
    FROM historical_sales
    GROUP BY date
)
SELECT
    sales_month,
    TO_CHAR(
        MAKE_DATE(2017, sales_month, 1),
        'Mon'
    ) AS month_name,
    COUNT(*) AS total_days,
    SUM(daily_units) AS total_units_sold,
    ROUND(AVG(daily_units), 2) AS avg_daily_units
FROM daily_sales
GROUP BY sales_month
ORDER BY sales_month;


-- ============================================================
-- ANALYSIS 09: YEAR-OVER-YEAR MONTHLY DEMAND COMPARISON
-- ============================================================
-- Objective:
-- Compare each month's demand with the same month
-- in the previous year.
--
-- Business Use:
-- Identify annual growth trends while accounting
-- for monthly seasonality.
-- ============================================================

WITH monthly_sales AS (
    SELECT
        "Year" AS sales_year,
        "Month" AS sales_month,
        SUM(sales) AS total_units_sold
    FROM historical_sales
    GROUP BY "Year", "Month"
),
yearly_comparison AS (
    SELECT
        sales_year,
        sales_month,
        total_units_sold,
        LAG(total_units_sold) OVER (
            PARTITION BY sales_month
            ORDER BY sales_year
        ) AS previous_year_units
    FROM monthly_sales
)
SELECT
    sales_year,
    TO_CHAR(
        MAKE_DATE(sales_year, sales_month, 1),
        'Mon'
    ) AS month_name,
    total_units_sold,
    previous_year_units,
    ROUND(
        (total_units_sold - previous_year_units) * 100.0
        / NULLIF(previous_year_units, 0),
        2
    ) AS yoy_growth_percent
FROM yearly_comparison
ORDER BY sales_year, sales_month;


-- ============================================================
-- ANALYSIS 10: STORE-WISE YEAR-OVER-YEAR GROWTH
-- ============================================================
-- Objective:
-- Calculate annual sales growth for each store.
--
-- Business Use:
-- Identify fastest-growing and slowest-growing stores.
-- ============================================================

WITH yearly_store_sales AS (
    SELECT
        store AS store_id,
        "Year" AS sales_year,
        SUM(sales) AS total_units_sold
    FROM historical_sales
    GROUP BY store, "Year"
),
store_growth AS (
    SELECT
        store_id,
        sales_year,
        total_units_sold,
        LAG(total_units_sold) OVER (
            PARTITION BY store_id
            ORDER BY sales_year
        ) AS previous_year_units
    FROM yearly_store_sales
)
SELECT
    store_id,
    sales_year,
    total_units_sold,
    previous_year_units,
    ROUND(
        (total_units_sold - previous_year_units) * 100.0
        / NULLIF(previous_year_units, 0),
        2
    ) AS yoy_growth_percent
FROM store_growth
ORDER BY store_id, sales_year;


-- ============================================================
-- ANALYSIS 11: ITEM-WISE YEAR-OVER-YEAR GROWTH
-- ============================================================
-- Objective:
-- Compare item-level demand between 2016 and 2017.
--
-- Business Use:
-- Identify fast-growing and slow-growing products
-- for demand forecasting and inventory planning.
-- ============================================================

WITH yearly_item_sales AS (
    SELECT
        item AS item_id,
        "Year" AS sales_year,
        SUM(sales) AS total_units_sold
    FROM historical_sales
    WHERE "Year" IN (2016, 2017)
    GROUP BY item, "Year"
),
item_comparison AS (
    SELECT
        item_id,
        SUM(
            CASE WHEN sales_year = 2016
                THEN total_units_sold ELSE 0 END
        ) AS sales_2016,
        SUM(
            CASE WHEN sales_year = 2017
                THEN total_units_sold ELSE 0 END
        ) AS sales_2017
    FROM yearly_item_sales
    GROUP BY item_id
)
SELECT
    item_id,
    sales_2016,
    sales_2017,
    sales_2017 - sales_2016 AS units_change,
    ROUND(
        (sales_2017 - sales_2016) * 100.0
        / NULLIF(sales_2016, 0),
        2
    ) AS yoy_growth_percent
FROM item_comparison
ORDER BY yoy_growth_percent DESC, item_id;


-- ============================================================
-- ANALYSIS 12: STORE-ITEM DEMAND COMBINATION ANALYSIS
-- ============================================================
-- Objective:
-- Identify the top 10 highest-demand store-item combinations.
--
-- Business Use:
-- Support store-specific inventory allocation and
-- localized demand planning.
-- ============================================================

SELECT
    store AS store_id,
    item AS item_id,
    SUM(sales) AS total_units_sold,
    COUNT(*) AS total_records,
    ROUND(AVG(sales), 2) AS avg_daily_units
FROM historical_sales
GROUP BY store, item
ORDER BY total_units_sold DESC
LIMIT 10;

-- ============================================================
-- ANALYSIS 12: STORE-ITEM DEMAND COMBINATION ANALYSIS
-- ============================================================
-- Objective:
-- Identify highest-demand store-item combinations.
--
-- Business Use:
-- Support store-specific inventory allocation,
-- stock planning, and demand forecasting.
-- ============================================================

SELECT
    store AS store_id,
    item AS item_id,
    SUM(sales) AS total_units_sold,
    COUNT(*) AS total_records,
    ROUND(AVG(sales), 2) AS avg_daily_units
FROM historical_sales
GROUP BY store, item
ORDER BY total_units_sold DESC
LIMIT 10;

-- ============================================================
-- ANALYSIS 13: ITEM-WISE DEMAND VARIABILITY
-- ============================================================
-- Objective:
-- Measure daily sales variability for each item.
--
-- Business Use:
-- Identify items with relatively unstable demand
-- to support inventory and forecasting decisions.
-- ============================================================

WITH item_demand_stats AS (
    SELECT
        item AS item_id,
        AVG(sales) AS avg_daily_demand,
        STDDEV_POP(sales) AS stddev_daily_demand
    FROM historical_sales
    GROUP BY item
)
SELECT
    item_id,
    ROUND(avg_daily_demand, 2) AS avg_daily_demand,
    ROUND(stddev_daily_demand, 2) AS stddev_daily_demand,
    ROUND(
        stddev_daily_demand * 100.0
        / NULLIF(avg_daily_demand, 0),
        2
    ) AS coefficient_of_variation_percent
FROM item_demand_stats
ORDER BY coefficient_of_variation_percent DESC;

-- ============================================================
-- ANALYSIS 14: STORE-ITEM DEMAND VARIABILITY
-- ============================================================
-- Objective:
-- Measure daily sales variability for each store-item
-- combination using the coefficient of variation.
--
-- Business Use:
-- Identify store-item combinations requiring closer
-- attention during inventory and demand planning.
-- ============================================================

WITH store_item_demand_stats AS (
    SELECT
        store AS store_id,
        item AS item_id,
        AVG(sales) AS avg_daily_demand,
        STDDEV_POP(sales) AS stddev_daily_demand
    FROM historical_sales
    GROUP BY store, item
)
SELECT
    store_id,
    item_id,
    ROUND(avg_daily_demand, 2) AS avg_daily_demand,
    ROUND(stddev_daily_demand, 2) AS stddev_daily_demand,
    ROUND(
        stddev_daily_demand * 100.0
        / NULLIF(avg_daily_demand, 0),
        2
    ) AS coefficient_of_variation_percent
FROM store_item_demand_stats
ORDER BY
    coefficient_of_variation_percent DESC,
    store_id,
    item_id;