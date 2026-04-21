-- =============================================================================
-- stg_order_items
--
-- Purpose:
--   Casts the raw order items table.  Each row represents a single product
--   line within an order (an order can have multiple items).
--
-- Grain: one row per order_id + order_item_id (composite key).
--
-- Why we need it:
--   price and freight_value must be NUMERIC for accurate financial aggregations
--   in the intermediate and mart layers.  String-typed numerics would silently
--   produce wrong SUM results.
-- =============================================================================

select
  cast(order_id as string) as order_id,
  cast(order_item_id as int64) as order_item_id,
  cast(product_id as string) as product_id,
  cast(seller_id as string) as seller_id,
  cast(shipping_limit_date as timestamp) as shipping_limit_date,
  cast(price as numeric) as price,
  cast(freight_value as numeric) as freight_value
from {{ source('raw_olist_data', 'olist_order_items_dataset') }}
