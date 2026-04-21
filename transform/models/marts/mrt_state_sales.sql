-- =============================================================================
-- mrt_state_sales
--
-- Purpose:
--   Aggregates all-time GMV, order volume, satisfaction, and delivery speed
--   by Brazilian state (customer location).  Primary mart for geographic
--   analysis and regional expansion planning.
--
-- Grain: one row per customer_state (all-time cumulative).
--
-- Why this mart:
--   Brazil is a geographically vast country with high logistics complexity.
--   Understanding which states generate the most revenue versus which have
--   the worst delivery times allows the business to:
--     1. Prioritise warehouse / fulfilment centre placement.
--     2. Negotiate regional carrier contracts.
--     3. Target marketing spend in high-potential but under-penetrated states.
--
-- Business insights delivered:
--   gross_merchandise_value -> regional revenue contribution
--   avg_review_score        -> regional satisfaction gap (often correlated with
--                              delivery distance from São Paulo fulfilment hubs)
--   avg_delivery_days       -> logistical efficiency by region
-- =============================================================================

select
  customer_state,
  count(distinct order_id)        as total_orders,
  -- GMV includes freight as it represents total customer spend
  sum(price + freight_value)      as gross_merchandise_value,
  avg(avg_review_score)           as avg_review_score,
  avg(delivery_days)              as avg_delivery_days
from {{ ref('int_order_enriched') }}
where customer_state is not null  -- exclude rows where customer geography is unknown
group by 1
