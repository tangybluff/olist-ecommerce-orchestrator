with orders as (
  select * from {{ ref('stg_orders') }}
),
items as (
  select * from {{ ref('stg_order_items') }}
),
payments as (
  select
    order_id,
    sum(payment_value) as total_payment_value,
    avg(payment_installments) as avg_payment_installments
  from {{ ref('stg_order_payments') }}
  group by 1
),
reviews as (
  select
    order_id,
    avg(review_score) as avg_review_score
  from {{ ref('stg_reviews') }}
  group by 1
),
customers as (
  select * from {{ ref('stg_customers') }}
),
products as (
  select * from {{ ref('stg_products') }}
),
categories as (
  select * from {{ ref('stg_category_translation') }}
),
sellers as (
  select * from {{ ref('stg_sellers') }}
)

select
  o.order_id,
  o.customer_id,
  o.order_status,
  o.order_purchase_timestamp,
  o.order_delivered_customer_date,
  c.customer_state,
  c.customer_city,
  i.order_item_id,
  i.product_id,
  i.seller_id,
  i.price,
  i.freight_value,
  p.product_category_name,
  ct.product_category_name_english,
  s.seller_state,
  s.seller_city,
  pay.total_payment_value,
  pay.avg_payment_installments,
  rv.avg_review_score,
  timestamp_diff(o.order_delivered_customer_date, o.order_purchase_timestamp, day) as delivery_days
from orders o
left join items i on o.order_id = i.order_id
left join customers c on o.customer_id = c.customer_id
left join products p on i.product_id = p.product_id
left join categories ct on p.product_category_name = ct.product_category_name
left join sellers s on i.seller_id = s.seller_id
left join payments pay on o.order_id = pay.order_id
left join reviews rv on o.order_id = rv.order_id
