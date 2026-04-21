-- =============================================================================
-- stg_customers
--
-- Purpose:
--   Casts the raw customers table.  Exposes customer geography (city, state)
--   which is the primary dimension used in the state-level sales mart.
--
-- Grain: one row per customer_id (transaction-scoped).
--
-- Note:
--   customer_unique_id identifies the real person across multiple orders.
--   customer_id is order-scoped (a repeat buyer gets a new customer_id per order).
--   Both are retained for flexibility in future models.
-- =============================================================================

select
  cast(customer_id as string) as customer_id,
  cast(customer_unique_id as string) as customer_unique_id,
  cast(customer_zip_code_prefix as string) as customer_zip_code_prefix,
  cast(customer_city as string) as customer_city,
  cast(customer_state as string) as customer_state
from {{ source('raw_olist_data', 'olist_customers_dataset') }}
