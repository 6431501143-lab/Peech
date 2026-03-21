-- ============================================================
-- OLIST E-COMMERCE SQL ANALYSIS PROJECT (SQLite Version)
-- Brazilian Marketplace · Data Analyst / Business Analyst Portfolio
-- Dataset: Sep 2016 – Aug 2018 | 99,441 Orders
-- ============================================================

-- ============================================================
-- SECTION 0: DATABASE SETUP & TABLE CREATION
-- ============================================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id         TEXT PRIMARY KEY,
    customer_unique_id  TEXT,
    customer_zip_code   TEXT,
    customer_city       TEXT,
    customer_state      TEXT
);

CREATE TABLE IF NOT EXISTS orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT,
    order_status                  TEXT,
    order_purchase_timestamp      TEXT,
    order_approved_at             TEXT,
    order_delivered_carrier_date  TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id              TEXT,
    order_item_id         INTEGER,
    product_id            TEXT,
    seller_id             TEXT,
    shipping_limit_date   TEXT,
    price                 REAL,
    freight_value         REAL
);

CREATE TABLE IF NOT EXISTS order_payments (
    order_id              TEXT,
    payment_sequential    INTEGER,
    payment_type          TEXT,
    payment_installments  INTEGER,
    payment_value         REAL
);


-- ============================================================
-- SECTION 1: OVERVIEW KPIs
-- Business question: What is the overall health of the marketplace?
-- ============================================================

-- 1.1 Total Orders, Revenue, Customers, Sellers
SELECT
    COUNT(DISTINCT o.order_id)      AS total_orders,
    COUNT(DISTINCT o.customer_id)   AS total_customers,
    COUNT(DISTINCT oi.seller_id)    AS total_sellers,
    COUNT(DISTINCT oi.product_id)   AS total_products,
    ROUND(SUM(oi.price), 2)         AS total_revenue,
    ROUND(SUM(oi.freight_value), 2) AS total_freight,
    ROUND(AVG(oi.price), 2)         AS avg_product_price,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- 1.2 Order Status Breakdown
SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- ============================================================
-- SECTION 2: SALES TREND ANALYSIS
-- Business question: How is the business growing month over month?
-- ============================================================

-- 2.1 Monthly Revenue & Order Count
-- Note: SQLite uses strftime() instead of DATE_TRUNC()
SELECT
    strftime('%Y-%m', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id)                     AS total_orders,
    ROUND(SUM(oi.price), 2)                        AS monthly_revenue,
    ROUND(AVG(oi.price), 2)                        AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
ORDER BY month;


-- 2.2 Day of Week Purchasing Pattern
-- Note: SQLite uses strftime('%w') → 0=Sunday, 1=Monday, ..., 6=Saturday
SELECT
    CASE strftime('%w', order_purchase_timestamp)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END                                          AS day_of_week,
    strftime('%w', order_purchase_timestamp)     AS dow_num,
    COUNT(*)                                     AS total_orders,
    ROUND(COUNT(*) * 100.0
          / (SELECT COUNT(*) FROM orders), 2)   AS pct
FROM orders
GROUP BY strftime('%w', order_purchase_timestamp)
ORDER BY dow_num;


-- 2.3 Hourly Purchase Distribution
-- Note: SQLite uses strftime('%H') instead of EXTRACT(HOUR FROM ...)
SELECT
    strftime('%H', order_purchase_timestamp) AS hour_of_day,
    COUNT(*)                                  AS total_orders
FROM orders
GROUP BY strftime('%H', order_purchase_timestamp)
ORDER BY hour_of_day;


-- ============================================================
-- SECTION 3: CUSTOMER ANALYSIS
-- Business question: Who are our customers and where are they?
-- ============================================================

-- 3.1 Customer Distribution by State
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id)                AS unique_customers,
    COUNT(DISTINCT o.order_id)                          AS total_orders,
    ROUND(SUM(oi.price), 2)                             AS total_revenue,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0
          / (SELECT COUNT(*) FROM orders
             WHERE order_status = 'delivered'), 2)      AS pct_of_orders
FROM customers c
JOIN orders o      ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id   = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_orders DESC
LIMIT 10;


-- 3.2 Customer Repeat Purchase Rate
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    order_count,
    COUNT(customer_unique_id)  AS num_customers,
    ROUND(COUNT(customer_unique_id) * 100.0
          / (SELECT COUNT(*) FROM customer_orders), 2) AS pct_of_customers
FROM customer_orders
GROUP BY order_count
ORDER BY order_count;


-- 3.3 Customer Lifetime Value (CLV) by State
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id)             AS unique_customers,
    ROUND(SUM(p.payment_value), 2)                   AS total_revenue,
    ROUND(AVG(p.payment_value), 2)                   AS avg_order_value,
    ROUND(SUM(p.payment_value)
          / COUNT(DISTINCT c.customer_unique_id), 2) AS clv_per_customer
FROM customers c
JOIN orders o          ON c.customer_id = o.customer_id
JOIN order_payments p  ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY clv_per_customer DESC
LIMIT 10;


-- ============================================================
-- SECTION 4: DELIVERY PERFORMANCE ANALYSIS
-- Business question: Are we delivering on time? Where do we fail?
-- ============================================================

-- 4.1 Overall Delivery Time Stats
-- Note: SQLite uses julianday() to calculate date differences in days
SELECT
    ROUND(AVG(julianday(order_delivered_customer_date)
              - julianday(order_purchase_timestamp)), 1)   AS avg_delivery_days,
    ROUND(MIN(julianday(order_delivered_customer_date)
              - julianday(order_purchase_timestamp)), 1)   AS min_delivery_days,
    ROUND(MAX(julianday(order_delivered_customer_date)
              - julianday(order_purchase_timestamp)), 1)   AS max_delivery_days,
    COUNT(CASE WHEN order_delivered_customer_date
                    > order_estimated_delivery_date
               THEN 1 END)                                 AS late_deliveries,
    COUNT(*)                                               AS total_delivered,
    ROUND(COUNT(CASE WHEN order_delivered_customer_date
                          > order_estimated_delivery_date
                     THEN 1 END) * 100.0 / COUNT(*), 2)   AS late_delivery_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL;


-- 4.2 On-time vs Late Delivery by State
SELECT
    c.customer_state,
    COUNT(*)                                                       AS total_deliveries,
    COUNT(CASE WHEN o.order_delivered_customer_date
                    <= o.order_estimated_delivery_date THEN 1 END) AS on_time,
    COUNT(CASE WHEN o.order_delivered_customer_date
                    > o.order_estimated_delivery_date THEN 1 END)  AS late,
    ROUND(COUNT(CASE WHEN o.order_delivered_customer_date
                          > o.order_estimated_delivery_date
                     THEN 1 END) * 100.0 / COUNT(*), 2)           AS late_pct,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
              - julianday(o.order_purchase_timestamp)), 1)         AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_pct DESC
LIMIT 10;


-- 4.3 Monthly Delivery Performance Trend
SELECT
    strftime('%Y-%m', order_purchase_timestamp)               AS month,
    COUNT(*)                                                   AS total_orders,
    ROUND(AVG(julianday(order_delivered_customer_date)
              - julianday(order_purchase_timestamp)), 1)       AS avg_delivery_days,
    ROUND(COUNT(CASE WHEN order_delivered_customer_date
                          > order_estimated_delivery_date
                     THEN 1 END) * 100.0 / COUNT(*), 2)       AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY strftime('%Y-%m', order_purchase_timestamp)
ORDER BY month;


-- ============================================================
-- SECTION 5: PAYMENT ANALYSIS
-- Business question: How do customers pay, and what are the patterns?
-- ============================================================

-- 5.1 Payment Method Distribution
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                              AS total_orders,
    ROUND(SUM(payment_value), 2)                         AS total_value,
    ROUND(AVG(payment_value), 2)                         AS avg_payment_value,
    ROUND(COUNT(DISTINCT order_id) * 100.0
          / (SELECT COUNT(DISTINCT order_id)
             FROM order_payments), 2)                    AS pct_of_orders
FROM order_payments
GROUP BY payment_type
ORDER BY total_orders DESC;


-- 5.2 Credit Card Installment Distribution
SELECT
    payment_installments,
    COUNT(*)                                              AS num_transactions,
    ROUND(SUM(payment_value), 2)                         AS total_value,
    ROUND(COUNT(*) * 100.0
          / (SELECT COUNT(*) FROM order_payments
             WHERE payment_type = 'credit_card'), 2)     AS pct
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;


-- 5.3 High-Value Orders Analysis (Top 10%)
WITH order_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment
    FROM order_payments
    GROUP BY order_id
),
p90 AS (
    SELECT total_payment AS p90_value
    FROM order_totals
    ORDER BY total_payment
    LIMIT 1
    OFFSET (SELECT CAST(COUNT(*) * 0.9 AS INTEGER) FROM order_totals)
)
SELECT
    ot.order_id,
    ROUND(ot.total_payment, 2)  AS total_payment,
    c.customer_state,
    o.order_status,
    op.payment_type,
    op.payment_installments
FROM order_totals ot
JOIN orders o          ON ot.order_id  = o.order_id
JOIN customers c       ON o.customer_id = c.customer_id
JOIN order_payments op ON ot.order_id  = op.order_id
                      AND op.payment_sequential = 1
WHERE ot.total_payment >= (SELECT p90_value FROM p90)
ORDER BY ot.total_payment DESC
LIMIT 20;


-- ============================================================
-- SECTION 6: SELLER PERFORMANCE ANALYSIS
-- Business question: Which sellers drive the most value?
-- ============================================================

-- 6.1 Top 10 Sellers by Revenue
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id)     AS total_orders,
    COUNT(oi.order_item_id)         AS total_items_sold,
    ROUND(SUM(oi.price), 2)         AS total_revenue,
    ROUND(AVG(oi.price), 2)         AS avg_item_price,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_charged
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id
ORDER BY total_revenue DESC
LIMIT 10;


-- 6.2 Seller Performance Segmentation
WITH seller_stats AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        ROUND(SUM(oi.price), 2)     AS total_revenue,
        ROUND(AVG(oi.price), 2)     AS avg_price
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
    seller_id,
    total_orders,
    total_revenue,
    avg_price,
    CASE
        WHEN total_revenue >= 50000 AND total_orders >= 100 THEN 'Top Seller'
        WHEN total_revenue >= 10000 OR  total_orders >= 50  THEN 'Growing Seller'
        WHEN total_orders  >= 10                            THEN 'Active Seller'
        ELSE 'New / Inactive Seller'
    END AS seller_segment
FROM seller_stats
ORDER BY total_revenue DESC;


-- ============================================================
-- SECTION 7: ADVANCED ANALYTICS
-- Business question: Cohort, ranking, and running totals
-- Note: SQLite supports Window Functions from version 3.25.0 (2018)
--       Check your version: SELECT sqlite_version();
-- ============================================================

-- 7.1 Running Total Revenue by Month
SELECT
    month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_revenue
FROM (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price), 2)                        AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
) monthly
ORDER BY month;


-- 7.2 3-Month Moving Average Revenue
SELECT
    month,
    monthly_revenue,
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3m
FROM (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price), 2)                        AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
) monthly
ORDER BY month;


-- 7.3 Rank Sellers Within Each State
WITH seller_state_revenue AS (
    SELECT
        c.customer_state,
        oi.seller_id,
        ROUND(SUM(oi.price), 2) AS revenue
    FROM order_items oi
    JOIN orders o    ON oi.order_id   = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state, oi.seller_id
)
SELECT
    customer_state,
    seller_id,
    revenue,
    RANK() OVER (PARTITION BY customer_state ORDER BY revenue DESC) AS state_rank
FROM seller_state_revenue
WHERE customer_state IN ('SP', 'RJ', 'MG')
ORDER BY customer_state, state_rank
LIMIT 30;


-- 7.4 Freight-to-Price Ratio
SELECT
    product_id,
    COUNT(order_id)                                              AS times_ordered,
    ROUND(AVG(price), 2)                                        AS avg_price,
    ROUND(AVG(freight_value), 2)                                AS avg_freight,
    ROUND(AVG(freight_value / NULLIF(price, 0)) * 100, 2)      AS freight_to_price_pct
FROM order_items
GROUP BY product_id
HAVING COUNT(order_id) >= 5
ORDER BY freight_to_price_pct DESC
LIMIT 20;


-- 7.5 Month-over-Month Revenue Growth (SQLite-compatible using LAG)
-- Note: LAG() is supported in SQLite 3.25.0+
SELECT
    month,
    monthly_revenue,
    prev_revenue,
    CASE
        WHEN prev_revenue IS NULL THEN NULL
        ELSE ROUND((monthly_revenue - prev_revenue) / prev_revenue * 100, 2)
    END AS mom_growth_pct
FROM (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price), 2)                        AS monthly_revenue,
        LAG(ROUND(SUM(oi.price), 2)) OVER (
            ORDER BY strftime('%Y-%m', o.order_purchase_timestamp)
        )                                              AS prev_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY strftime('%Y-%m', o.order_purchase_timestamp)
) t
ORDER BY month;


-- ============================================================
-- SECTION 8: BUSINESS INSIGHTS SUMMARY VIEWS
-- Ready-to-use views for BI dashboards
-- ============================================================

-- View 1: Monthly KPI Summary
CREATE VIEW IF NOT EXISTS vw_monthly_kpi AS
SELECT
    strftime('%Y-%m', o.order_purchase_timestamp)          AS month,
    COUNT(DISTINCT o.order_id)                              AS total_orders,
    COUNT(DISTINCT o.customer_id)                          AS unique_customers,
    ROUND(SUM(oi.price), 2)                                AS gross_revenue,
    ROUND(SUM(oi.freight_value), 2)                        AS total_freight,
    ROUND(AVG(oi.price), 2)                                AS avg_order_value,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
              - julianday(o.order_purchase_timestamp)), 1) AS avg_delivery_days,
    COUNT(CASE WHEN o.order_delivered_customer_date
                    > o.order_estimated_delivery_date
               THEN 1 END)                                 AS late_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY strftime('%Y-%m', o.order_purchase_timestamp);


-- View 2: Customer Segmentation
CREATE VIEW IF NOT EXISTS vw_customer_segments AS
WITH customer_stats AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id)      AS total_orders,
        ROUND(SUM(p.payment_value), 2)  AS total_spent,
        MAX(o.order_purchase_timestamp) AS last_purchase
    FROM customers c
    JOIN orders o         ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id    = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state
)
SELECT
    customer_unique_id,
    customer_state,
    total_orders,
    total_spent,
    last_purchase,
    CASE
        WHEN total_orders >= 3 AND total_spent >= 500 THEN 'VIP'
        WHEN total_orders >= 2 OR  total_spent >= 200 THEN 'Loyal'
        WHEN total_orders  = 1 AND total_spent >= 100 THEN 'Promising'
        ELSE 'One-Time Buyer'
    END AS customer_segment
FROM customer_stats;
