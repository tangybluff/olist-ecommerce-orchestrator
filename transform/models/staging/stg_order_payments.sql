-- =============================================================================
-- stg_order_payments
--
-- Purpose:
--   Casts the raw payments table.  An order can have multiple payment rows
--   (e.g. a credit card split into instalments, plus a voucher).
--
-- Grain: one row per order_id + payment_sequential.
--
-- Why we need it:
--   payment_value must be NUMERIC for SUM aggregations.  The intermediate
--   layer aggregates this to order-level totals before joining.
-- =============================================================================

select
  cast(order_id as string) as order_id,
  cast(payment_sequential as int64) as payment_sequential,
  cast(payment_type as string) as payment_type,
  cast(payment_installments as int64) as payment_installments,
  cast(payment_value as numeric) as payment_value
from {{ source('raw_olist_data', 'olist_order_payments_dataset') }}
