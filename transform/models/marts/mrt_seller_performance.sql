select
  seller_id,
  seller_state,
  count(distinct order_id) as total_orders,
  sum(price) as total_item_revenue,
  sum(freight_value) as total_freight_value,
  avg(avg_review_score) as avg_review_score,
  avg(delivery_days) as avg_delivery_days
from {{ ref('int_order_enriched') }}
where seller_id is not null
group by 1, 2
