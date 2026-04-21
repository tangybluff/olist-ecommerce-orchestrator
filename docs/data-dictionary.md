# Data Dictionary

## Raw Layer (BigQuery dataset: raw_olist_data)

### olist_orders_dataset

- order_id: order identifier
- customer_id: customer foreign key
- order_status: order lifecycle status
- order_purchase_timestamp: purchase timestamp
- order_approved_at: payment approval timestamp
- order_delivered_carrier_date: handoff to carrier timestamp
- order_delivered_customer_date: final delivery timestamp
- order_estimated_delivery_date: estimated delivery timestamp

### olist_order_items_dataset

- order_id: order foreign key
- order_item_id: line item id inside order
- product_id: product foreign key
- seller_id: seller foreign key
- shipping_limit_date: seller shipping deadline
- price: item price
- freight_value: freight amount

### olist_order_payments_dataset

- order_id: order foreign key
- payment_sequential: payment sequence number
- payment_type: payment method
- payment_installments: number of installments
- payment_value: payment amount

### olist_order_reviews_dataset

- review_id: review identifier
- order_id: order foreign key
- review_score: review score (1-5)
- review_comment_title: review title
- review_comment_message: review message
- review_creation_date: review creation date
- review_answer_timestamp: review answered timestamp

### olist_customers_dataset

- customer_id: customer identifier
- customer_unique_id: persistent customer identity
- customer_zip_code_prefix: zip prefix
- customer_city: city
- customer_state: state code

### olist_products_dataset

- product_id: product identifier
- product_category_name: category in Portuguese
- product_name_lenght: product name length (source typo)
- product_description_lenght: product description length (source typo)
- product_photos_qty: number of photos
- product_weight_g: weight in grams
- product_length_cm: length in cm
- product_height_cm: height in cm
- product_width_cm: width in cm

### olist_sellers_dataset

- seller_id: seller identifier
- seller_zip_code_prefix: zip prefix
- seller_city: city
- seller_state: state code

### product_category_name_translation

- product_category_name: category name in Portuguese
- product_category_name_english: translated category

## Staging Layer

Staging models normalize data types and standardize naming.

- stg_orders
- stg_order_items
- stg_order_payments
- stg_reviews
- stg_customers
- stg_products
- stg_sellers
- stg_category_translation

## Intermediate Layer

### int_order_enriched

Enriched order-line grain model joining orders, items, payments, customers, products, sellers, and review aggregates.

Key fields:

- order_id
- customer_id
- order_status
- order_purchase_timestamp
- customer_state
- product_id
- seller_id
- price
- freight_value
- total_payment_value
- avg_payment_installments
- avg_review_score
- delivery_days

## Marts Layer

### mrt_daily_sales

Daily KPI rollup.

- order_date
- total_orders
- total_items
- gross_item_revenue
- total_freight
- gross_merchandise_value
- avg_review_score
- avg_delivery_days

### mrt_state_sales

State-level KPI rollup.

- customer_state
- total_orders
- gross_merchandise_value
- avg_review_score
- avg_delivery_days

### mrt_seller_performance

Seller-level KPI rollup.

- seller_id
- seller_state
- total_orders
- total_item_revenue
- total_freight_value
- avg_review_score
- avg_delivery_days
