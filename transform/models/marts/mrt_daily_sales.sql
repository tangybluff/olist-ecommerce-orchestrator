select
  date(order_purchase_timestamp) as order_date,
  count(distinct order_id) as total_orders,
  count(*) as total_items,
  sum(price) as gross_item_revenue,
  sum(freight_value) as total_freight,
  sum(price + freight_value) as gross_merchandise_value,
  avg(avg_review_score) as avg_review_score,
  avg(delivery_days) as avg_delivery_days
from {{ ref('int_order_enriched') }}
group by 1
