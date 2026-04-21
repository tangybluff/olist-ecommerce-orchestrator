-- =============================================================================
-- stg_reviews
--
-- Purpose:
--   Casts the raw order reviews table.  review_score (1–5) is the primary
--   satisfaction signal surfaced in every mart as avg_review_score.
--
-- Grain: one row per review_id (multiple reviews can exist per order).
--
-- Why we need it:
--   Customer satisfaction scores are aggregated to order level in the
--   intermediate layer and then surfaced in daily, seller, and state marts
--   to correlate delivery performance with satisfaction.
-- =============================================================================

select
  cast(review_id as string) as review_id,
  cast(order_id as string) as order_id,
  cast(review_score as int64) as review_score,
  cast(review_comment_title as string) as review_comment_title,
  cast(review_comment_message as string) as review_comment_message,
  cast(review_creation_date as timestamp) as review_creation_date,
  cast(review_answer_timestamp as timestamp) as review_answer_timestamp
from {{ source('raw_olist_data', 'olist_order_reviews_dataset') }}
