select
  cast(seller_id as string) as seller_id,
  cast(seller_zip_code_prefix as string) as seller_zip_code_prefix,
  cast(seller_city as string) as seller_city,
  cast(seller_state as string) as seller_state
from {{ source('raw_olist_data', 'olist_sellers_dataset') }}
