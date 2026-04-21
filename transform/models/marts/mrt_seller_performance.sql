-- =============================================================================
-- mrt_seller_performance
--
-- Purpose:
--   Aggregates all-time order and revenue metrics per seller, enriched with
--   satisfaction scores and delivery speed.
--
-- Grain: one row per seller_id + seller_state (all-time cumulative).
--
-- Why this mart:
--   Olist is a marketplace platform – seller quality directly determines
--   platform reputation.  This mart powers seller scorecards and enables
--   the operations team to identify underperforming sellers (low review
--   scores, slow delivery) and top earners eligible for incentive programmes.
--
-- Business insights delivered:
--   total_orders         -> seller activity / popularity
--   total_item_revenue   -> seller GMV contribution to the platform
--   avg_review_score     -> proxy for seller reliability and product quality
--   avg_delivery_days    -> fulfilment speed; slow sellers hurt platform NPS
-- =============================================================================

select
  seller_id,
  seller_state,
  count(distinct order_id)   as total_orders,
  sum(price)                 as total_item_revenue,
  sum(freight_value)         as total_freight_value,
  avg(avg_review_score)      as avg_review_score,
  avg(delivery_days)         as avg_delivery_days
from {{ ref('int_order_enriched') }}
where seller_id is not null   -- exclude items where seller mapping is missing
group by 1, 2
