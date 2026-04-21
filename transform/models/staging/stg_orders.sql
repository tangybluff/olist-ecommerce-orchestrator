-- =============================================================================
-- stg_orders
--
-- Purpose:
--   Light type-casting layer over the raw orders table.  Converts string
--   timestamps to TIMESTAMP type and ensures IDs are typed as strings.
--
-- Grain: one row per order (order_id is the primary key).
--
-- Why we need it:
--   Raw CSV data loaded by dlt may arrive with loose typing.  Explicit casts
--   here prevent type errors in downstream joins and ensure consistent data
--   types across the transformation layer.
-- =============================================================================

select
  cast(order_id as string) as order_id,
  cast(customer_id as string) as customer_id,
  cast(order_status as string) as order_status,
  cast(order_purchase_timestamp as timestamp) as order_purchase_timestamp,
  cast(order_approved_at as timestamp) as order_approved_at,
  cast(order_delivered_carrier_date as timestamp) as order_delivered_carrier_date,
  cast(order_delivered_customer_date as timestamp) as order_delivered_customer_date,
  cast(order_estimated_delivery_date as timestamp) as order_estimated_delivery_date
from {{ source('raw_olist_data', 'olist_orders_dataset') }}
