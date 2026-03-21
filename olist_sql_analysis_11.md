#  Olist E-Commerce SQL Analysis

## Project Overview

This project analyzes Olist, a Brazilian e-commerce marketplace, using SQL to extract business insights from 4 relational datasets covering orders, products, payments, and customers.

> Dataset: 99,441 orders · 26 Brazilian states · Sep 2016 – Aug 2018

---

##  Dataset Schema

```
customers          orders             order_items        order_payments
─────────────      ──────────────     ───────────────    ──────────────────
customer_id    ←── customer_id        order_id       ──→ order_id
customer_         order_id        ──→ order_item_id      payment_sequential
unique_id         order_status        product_id          payment_type
customer_city     purchase_ts         seller_id           payment_installments
customer_state    approved_at         price               payment_value
                  delivered_date      freight_value
                  estimated_date
```


## Section 1 — Overview KPIs

> **Business Question:** What is the overall health of the marketplace?

### 1.1 Total Orders, Revenue, Customers & Sellers

```sql
SELECT
    COUNT(DISTINCT o.order_id)          AS total_orders,
    COUNT(DISTINCT o.customer_id)       AS total_customers,
    COUNT(DISTINCT oi.seller_id)        AS total_sellers,
    COUNT(DISTINCT oi.product_id)       AS total_products,
    ROUND(SUM(oi.price), 2)             AS total_revenue,
    ROUND(SUM(oi.freight_value), 2)     AS total_freight,
    ROUND(AVG(oi.price), 2)             AS avg_product_price,
    ROUND(AVG(oi.freight_value), 2)     AS avg_freight_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';
```

<img width="1135" height="107" alt="image" src="https://github.com/user-attachments/assets/0adef090-078e-4ebb-940f-014745002883" />


---

### 1.2 Order Status Breakdown

```sql
SELECT
    order_status,
    COUNT(*)                                            AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)  AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;
```

**Result:**


<img width="428" height="377" alt="image" src="https://github.com/user-attachments/assets/67b1e52c-f00a-49f7-8e12-dcdb5e13da03" />

---

## Section 2 — Sales Trend Analysis

> **Business Question:** How is the business growing month over month?

### 2.1 Monthly Revenue & MoM Growth

```sql
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)  AS month,
    COUNT(DISTINCT o.order_id)                        AS total_orders,
    ROUND(SUM(oi.price), 2)                           AS monthly_revenue,
    ROUND(AVG(oi.price), 2)                           AS avg_order_value,
    ROUND(
        (SUM(oi.price) - LAG(SUM(oi.price)) OVER (ORDER BY DATE_TRUNC('month', o.order_purchase_timestamp)))
        / LAG(SUM(oi.price)) OVER (ORDER BY DATE_TRUNC('month', o.order_purchase_timestamp)) * 100
    , 2)                                              AS mom_growth_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;
```

**Result:**

![2.1_monthly_revenue](images/2_1_monthly_revenue.png)

---

### 2.2 Day of Week Purchasing Pattern

```sql
SELECT
    TO_CHAR(order_purchase_timestamp, 'Day') AS day_of_week,
    EXTRACT(DOW FROM order_purchase_timestamp) AS dow_num,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM orders
GROUP BY TO_CHAR(order_purchase_timestamp, 'Day'),
         EXTRACT(DOW FROM order_purchase_timestamp)
ORDER BY dow_num;
```

**Result:**

![2.2_day_of_week](images/2_2_day_of_week.png)

---

### 2.3 Hourly Purchase Distribution

```sql
SELECT
    EXTRACT(HOUR FROM order_purchase_timestamp) AS hour_of_day,
    COUNT(*) AS total_orders
FROM orders
GROUP BY EXTRACT(HOUR FROM order_purchase_timestamp)
ORDER BY hour_of_day;
```

**Result:**

![2.3_hourly_orders](images/2_3_hourly_orders.png)

---

## Section 3 — Customer Analysis

> **Business Question:** Who are our customers and where are they?

### 3.1 Customer Distribution by State

```sql
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id)                     AS unique_customers,
    COUNT(DISTINCT o.order_id)                               AS total_orders,
    ROUND(SUM(oi.price), 2)                                  AS total_revenue,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0
          / SUM(COUNT(DISTINCT o.order_id)) OVER (), 2)      AS pct_of_orders
FROM customers c
JOIN orders o     ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id  = oi.order_id
GROUP BY c.customer_state
ORDER BY total_orders DESC
LIMIT 10;
```

**Result:**

![3.1_customer_by_state](images/3_1_customer_by_state.png)

---

### 3.2 Customer Repeat Purchase Rate

```sql
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
    COUNT(customer_unique_id)                              AS num_customers,
    ROUND(COUNT(customer_unique_id) * 100.0
          / SUM(COUNT(customer_unique_id)) OVER(), 2)      AS pct_of_customers
FROM customer_orders
GROUP BY order_count
ORDER BY order_count;
```

**Result:**

![3.2_repeat_purchase](images/3_2_repeat_purchase.png)

---

### 3.3 Customer Lifetime Value (CLV) by State

```sql
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id)              AS unique_customers,
    ROUND(SUM(p.payment_value), 2)                    AS total_revenue,
    ROUND(AVG(p.payment_value), 2)                    AS avg_order_value,
    ROUND(SUM(p.payment_value)
          / COUNT(DISTINCT c.customer_unique_id), 2)  AS clv_per_customer
FROM customers c
JOIN orders o         ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id    = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY clv_per_customer DESC
LIMIT 10;
```

**Result:**

![3.3_clv_by_state](images/3_3_clv_by_state.png)

---

## Section 4 — Delivery Performance

> **Business Question:** Are we delivering on time? Where do we fail?

### 4.1 Overall Delivery Time Stats

```sql
SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM
        (order_delivered_customer_date - order_purchase_timestamp)) / 86400), 1)  AS avg_delivery_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
        (ORDER BY EXTRACT(EPOCH FROM
        (order_delivered_customer_date - order_purchase_timestamp)) / 86400), 1)  AS median_delivery_days,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP
        (ORDER BY EXTRACT(EPOCH FROM
        (order_delivered_customer_date - order_purchase_timestamp)) / 86400), 1)  AS p90_delivery_days,
    COUNT(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
               THEN 1 END)                                                        AS late_deliveries,
    COUNT(*)                                                                      AS total_delivered,
    ROUND(COUNT(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                     THEN 1 END) * 100.0 / COUNT(*), 2)                          AS late_delivery_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL;
```

**Result:**

![4.1_delivery_stats](images/4_1_delivery_stats.png)

---

### 4.2 On-time vs Late Delivery by State

```sql
SELECT
    c.customer_state,
    COUNT(*)                                                    AS total_deliveries,
    COUNT(CASE WHEN o.order_delivered_customer_date
                    <= o.order_estimated_delivery_date THEN 1 END)  AS on_time,
    COUNT(CASE WHEN o.order_delivered_customer_date
                    > o.order_estimated_delivery_date THEN 1 END)   AS late,
    ROUND(COUNT(CASE WHEN o.order_delivered_customer_date
                          > o.order_estimated_delivery_date THEN 1 END)
          * 100.0 / COUNT(*), 2)                                AS late_pct,
    ROUND(AVG(EXTRACT(EPOCH FROM
        (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400), 1) AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_pct DESC
LIMIT 10;
```

**Result:**

![4.2_late_by_state](images/4_2_late_by_state.png)

---

### 4.3 Monthly Delivery Performance Trend

```sql
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS month,
    COUNT(*)                                       AS total_orders,
    ROUND(AVG(EXTRACT(EPOCH FROM
        (order_delivered_customer_date - order_purchase_timestamp)) / 86400), 1)  AS avg_delivery_days,
    ROUND(COUNT(CASE WHEN order_delivered_customer_date
                          > order_estimated_delivery_date THEN 1 END)
          * 100.0 / COUNT(*), 2)                  AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY month;
```

**Result:**

![4.3_monthly_delivery](images/4_3_monthly_delivery.png)

---

## Section 5 — Payment Analysis

> **Business Question:** How do customers pay, and what are the patterns?

### 5.1 Payment Method Distribution

```sql
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                                    AS total_orders,
    ROUND(SUM(payment_value), 2)                               AS total_value,
    ROUND(AVG(payment_value), 2)                               AS avg_payment_value,
    ROUND(COUNT(DISTINCT order_id) * 100.0
          / SUM(COUNT(DISTINCT order_id)) OVER(), 2)           AS pct_of_orders
FROM order_payments
GROUP BY payment_type
ORDER BY total_orders DESC;
```

**Result:**

![5.1_payment_methods](images/5_1_payment_methods.png)

---

### 5.2 Credit Card Installment Distribution

```sql
SELECT
    payment_installments,
    COUNT(*)                                                    AS num_transactions,
    ROUND(SUM(payment_value), 2)                               AS total_value,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)          AS pct
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;
```

**Result:**

![5.2_installments](images/5_2_installments.png)

---

### 5.3 High-Value Orders Analysis (Top 10%)

```sql
WITH order_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment
    FROM order_payments
    GROUP BY order_id
),
percentiles AS (
    SELECT PERCENTILE_CONT(0.9) WITHIN GROUP
           (ORDER BY total_payment) AS p90_value
    FROM order_totals
)
SELECT
    ot.order_id,
    ot.total_payment,
    c.customer_state,
    o.order_status,
    op.payment_type,
    op.payment_installments
FROM order_totals ot
JOIN orders o         ON ot.order_id = o.order_id
JOIN customers c      ON o.customer_id = c.customer_id
JOIN order_payments op ON ot.order_id = op.order_id AND op.payment_sequential = 1
CROSS JOIN percentiles p
WHERE ot.total_payment >= p.p90_value
ORDER BY ot.total_payment DESC
LIMIT 20;
```

**Result:**

![5.3_high_value_orders](images/5_3_high_value_orders.png)

---

## Section 6 — Seller Performance

> **Business Question:** Which sellers drive the most value?

### 6.1 Top 10 Sellers by Revenue

```sql
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
```

**Result:**

![6.1_top_sellers](images/6_1_top_sellers.png)

---

### 6.2 Seller Performance Segmentation

```sql
WITH seller_stats AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id)     AS total_orders,
        ROUND(SUM(oi.price), 2)         AS total_revenue,
        ROUND(AVG(oi.price), 2)         AS avg_price
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
```

**Result:**

![6.2_seller_segments](images/6_2_seller_segments.png)

---

## Section 7 — Advanced Analytics

> **Business Question:** Cohort retention, running totals, and ranking.

### 7.1 Running Total Revenue by Month

```sql
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)  AS month,
    ROUND(SUM(oi.price), 2)                           AS monthly_revenue,
    ROUND(SUM(SUM(oi.price)) OVER (
        ORDER BY DATE_TRUNC('month', o.order_purchase_timestamp)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2)                                             AS running_total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;
```

**Result:**

![7.1_running_total](images/7_1_running_total.png)

---

### 7.2 3-Month Moving Average Revenue

```sql
SELECT
    month,
    monthly_revenue,
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3m
FROM (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price), 2)                         AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
) monthly
ORDER BY month;
```

**Result:**

![7.2_moving_average](images/7_2_moving_average.png)

---

### 7.3 Customer Cohort Retention Analysis

```sql
WITH first_purchase AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),
customer_activity AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
),
cohort_data AS (
    SELECT
        fp.cohort_month,
        ca.activity_month,
        COUNT(DISTINCT ca.customer_unique_id)                          AS active_customers,
        EXTRACT(MONTH FROM AGE(ca.activity_month, fp.cohort_month))    AS month_number
    FROM first_purchase fp
    JOIN customer_activity ca ON fp.customer_unique_id = ca.customer_unique_id
    GROUP BY fp.cohort_month, ca.activity_month,
             EXTRACT(MONTH FROM AGE(ca.activity_month, fp.cohort_month))
)
SELECT
    cohort_month,
    month_number,
    active_customers,
    FIRST_VALUE(active_customers) OVER
        (PARTITION BY cohort_month ORDER BY month_number)          AS cohort_size,
    ROUND(active_customers * 100.0 /
        FIRST_VALUE(active_customers) OVER
        (PARTITION BY cohort_month ORDER BY month_number), 2)      AS retention_rate_pct
FROM cohort_data
WHERE month_number BETWEEN 0 AND 5
ORDER BY cohort_month, month_number;
```

**Result:**

![7.3_cohort_retention](images/7_3_cohort_retention.png)

---

### 7.4 Rank Sellers Within Each State

```sql
WITH seller_state_revenue AS (
    SELECT
        c.customer_state,
        oi.seller_id,
        ROUND(SUM(oi.price), 2) AS revenue
    FROM order_items oi
    JOIN orders o    ON oi.order_id  = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state, oi.seller_id
)
SELECT
    customer_state,
    seller_id,
    revenue,
    RANK() OVER (PARTITION BY customer_state ORDER BY revenue DESC)        AS state_rank,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (PARTITION BY customer_state), 2) AS state_revenue_share_pct
FROM seller_state_revenue
WHERE customer_state IN ('SP', 'RJ', 'MG')
ORDER BY customer_state, state_rank
LIMIT 30;
```

**Result:**

![7.4_seller_rank_by_state](images/7_4_seller_rank_by_state.png)

---

### 7.5 Freight-to-Price Ratio

```sql
SELECT
    product_id,
    COUNT(order_id)                                         AS times_ordered,
    ROUND(AVG(price), 2)                                   AS avg_price,
    ROUND(AVG(freight_value), 2)                           AS avg_freight,
    ROUND(AVG(freight_value / NULLIF(price, 0)) * 100, 2) AS freight_to_price_pct,
    NTILE(4) OVER (ORDER BY AVG(freight_value / NULLIF(price, 0))) AS freight_quartile
FROM order_items
GROUP BY product_id
HAVING COUNT(order_id) >= 5
ORDER BY freight_to_price_pct DESC
LIMIT 20;
```

**Result:**

![7.5_freight_ratio](images/7_5_freight_ratio.png)

---

## Section 8 — Views for BI Dashboard

> **Business Question:** How do we build reusable queries for dashboards?

### 8.1 Monthly KPI Summary View

```sql
CREATE OR REPLACE VIEW vw_monthly_kpi AS
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp)  AS month,
    COUNT(DISTINCT o.order_id)                        AS total_orders,
    COUNT(DISTINCT o.customer_id)                     AS unique_customers,
    ROUND(SUM(oi.price), 2)                           AS gross_revenue,
    ROUND(SUM(oi.freight_value), 2)                   AS total_freight,
    ROUND(AVG(oi.price), 2)                           AS avg_order_value,
    ROUND(AVG(EXTRACT(EPOCH FROM
        (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400), 1) AS avg_delivery_days,
    COUNT(CASE WHEN o.order_delivered_customer_date
                    > o.order_estimated_delivery_date THEN 1 END) AS late_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp);
```

**Result:**

![8.1_monthly_kpi_view](images/8_1_monthly_kpi_view.png)

---

### 8.2 Customer Segmentation View

```sql
CREATE OR REPLACE VIEW vw_customer_segments AS
WITH customer_stats AS (
    SELECT
        c.customer_unique_id,
        c.customer_state,
        COUNT(DISTINCT o.order_id)     AS total_orders,
        ROUND(SUM(p.payment_value), 2) AS total_spent,
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
```

**Result:**

![8.2_customer_segment_view](images/8_2_customer_segment_view.png)

---

## 💡 Key Insights & Recommendations

| # | Insight | Recommendation |
|---|---|---|
| 1 | 🚀 Nov 2017 revenue surged **+52% MoM** (Black Friday) | Plan inventory & logistics 6–8 weeks ahead each year |
| 2 | 🌎 SP + RJ + MG = **66.6%** of all orders | Launch regional campaigns in BA, GO, DF to diversify |
| 3 | 💳 **73.9%** pay by credit card; 50.5% pay in full | Offer 0% interest 2–3x installments to boost conversion |
| 4 | 📦 **78.6%** of orders contain only 1 item | Implement "Frequently Bought Together" to increase AOV |
| 5 | ⏰ Peak purchase hours: **10:00–21:00** (peak at 16:00) | Schedule flash sales & push notifications at 16:00 |
| 6 | 🚚 Freight = **16.5%** of avg product price | Introduce free shipping threshold (e.g., over R$150) |

---

## 🚀 How to Run

```bash
# 1. Create database
createdb olist_db

# 2. Connect
psql -d olist_db

# 3. Import data
\COPY customers     FROM 'data/olist_customers_dataset.csv'      CSV HEADER;
\COPY orders        FROM 'data/olist_orders_dataset.csv'         CSV HEADER;
\COPY order_items   FROM 'data/olist_order_items_dataset.csv'    CSV HEADER;
\COPY order_payments FROM 'data/olist_order_payments_dataset.csv' CSV HEADER;

# 4. Run queries
\i olist_sql_project.sql
```

---

## 📂 Project Structure

```
olist-sql-analysis/
│
├── olist_sql_analysis.md        ← This file
├── olist_sql_project.sql        ← Raw SQL file
├── README.md                    ← Project overview
│
├── data/
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_order_payments_dataset.csv
│   └── olist_customers_dataset.csv
│
└── images/                      ← Screenshot results (replace placeholders)
    ├── 1_1_overview_kpis.png
    ├── 1_2_order_status.png
    ├── 2_1_monthly_revenue.png
    └── ...
```

---

## 🛠️ SQL Techniques Used

| Technique | Queries |
|---|---|
| `LAG()`, `LEAD()` | MoM Growth (2.1) |
| `RANK()`, `DENSE_RANK()` | Seller Ranking (7.4) |
| `SUM() OVER()`, `AVG() OVER()` | Running Total, Moving Average (7.1, 7.2) |
| `FIRST_VALUE()` | Cohort Retention (7.3) |
| `NTILE()` | Freight Quartile (7.5) |
| `PERCENTILE_CONT()` | Delivery P50/P90 (4.1) |
| `WITH ... AS ()` (CTE) | Cohort, CLV, High-Value Orders |
| `CASE WHEN` | Segmentation, Status Breakdown |
| `DATE_TRUNC()`, `EXTRACT()`, `AGE()` | All time-based analyses |
| `CREATE OR REPLACE VIEW` | BI Dashboard Views (8.1, 8.2) |

---

*Dataset source: [Olist Brazilian E-Commerce — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)*
