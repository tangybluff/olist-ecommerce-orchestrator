-- =============================================================================
-- stg_category_translation
--
-- Purpose:
--   Maps Portuguese product category names to English equivalents.
--   This is a small reference/lookup table (~75 rows).
--
-- Grain: one row per product_category_name (Portuguese name is the key).
--
-- Why we need it:
--   The Olist dataset ships with Portuguese categories.  Translating them
--   here means all downstream models and BI dashboards display English
--   category labels without a separate lookup step.
-- =============================================================================

select
  cast(product_category_name as string) as product_category_name,
  cast(product_category_name_english as string) as product_category_name_english
from {{ source('raw_olist_data', 'product_category_name_translation') }}
