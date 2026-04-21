select
  customer_state,
  count(distinct order_id) as total_orders,
  sum(price + freight_value) as gross_merchandise_value,
  avg(avg_review_score) as avg_review_score,
  avg(delivery_days) as avg_delivery_days
from {{ ref('int_order_enriched') }}
where customer_state is not null
group by 1
