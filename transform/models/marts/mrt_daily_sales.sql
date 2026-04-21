-- =============================================================================
-- mrt_daily_sales
--
-- Purpose:
--   Aggregates order-item level data to a daily time series of sales KPIs.
--   This is the primary mart for time-series dashboards and trend analysis.
--
-- Grain: one row per calendar date (order_date).
--
-- Why this mart:
--   Daily granularity is the most actionable cadence for an ecommerce ops team.
--   It enables monitoring of day-over-day GMV trends, seasonal peaks (Black
--   Friday, holidays), and early detection of drops in order volume or quality.
--
-- Business insights delivered:
--   total_orders            -> volume trend; spikes indicate promotions or viral moments
--   gross_merchandise_value -> revenue health including freight component
--   avg_review_score        -> daily CSAT signal correlated with delivery issues
--   avg_delivery_days       -> fulfilment efficiency over time
-- =============================================================================

select
  date(order_purchase_timestamp)        as order_date,
  count(distinct order_id)              as total_orders,
  count(*)                              as total_items,
  sum(price)                            as gross_item_revenue,
  sum(freight_value)                    as total_freight,
  -- GMV = product revenue + freight; the standard top-line ecommerce metric
  sum(price + freight_value)            as gross_merchandise_value,
  avg(avg_review_score)                 as avg_review_score,
  avg(delivery_days)                    as avg_delivery_days
from {{ ref('int_order_enriched') }}
group by 1
