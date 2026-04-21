-- =============================================================================
-- stg_products
--
-- Purpose:
--   Casts the raw products table and corrects typos in the original Kaggle
--   column names ('lenght' -> 'length').
--
-- Grain: one row per product_id.
--
-- Why we need it:
--   product_category_name (Portuguese) is joined to stg_category_translation
--   in the intermediate layer to produce the English category name used in
--   mart filters and dashboards.
-- =============================================================================

select
  cast(product_id as string) as product_id,
  cast(product_category_name as string) as product_category_name,
  cast(product_name_lenght as int64) as product_name_length,        -- source typo corrected
  cast(product_description_lenght as int64) as product_description_length,
  cast(product_photos_qty as int64) as product_photos_qty,
  cast(product_weight_g as int64) as product_weight_g,
  cast(product_length_cm as int64) as product_length_cm,
  cast(product_height_cm as int64) as product_height_cm,
  cast(product_width_cm as int64) as product_width_cm
from {{ source('raw_olist_data', 'olist_products_dataset') }}
