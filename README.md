# Olist E-commerce Data Platform

End-to-end ELT data platform for the [Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) using:

- **Ingestion:** Python + kagglehub + dlt (Kaggle → GCS → BigQuery)
- **Transformation:** dbt Core (staging → intermediate → marts)
- **Orchestration:** Dagster daily schedule
- **Infrastructure:** Terraform on GCP (GCS, BigQuery, Secret Manager)
- **Containerisation:** Docker / Docker Compose

---

## Why a pipeline like this matters for data engineering

Raw operational data—CSV exports, API feeds, database dumps—is rarely in a shape that analysts or business intelligence tools can use directly. It has wrong types, missing joins, duplicate keys, inconsistent naming, and no documented lineage. A modern ELT pipeline solves this by:

1. **Extracting and loading raw data as-is** (via dlt) so the original source of truth is always preserved in BigQuery and can be reprocessed if transformation logic changes.
2. **Transforming in the warehouse** (via dbt) rather than in application code, which means transformations are version-controlled SQL, testable, documentable, and visible to the whole team.
3. **Orchestrating end-to-end** (via Dagster) so the pipeline runs automatically, dependencies are enforced (dbt never runs if ingestion fails), failures surface immediately, and historical runs can be re-executed with one click.

Without this structure, analysts write one-off queries against raw tables, data quality issues go undetected until a metric looks wrong in a board meeting, and the same business logic gets duplicated across a dozen spreadsheets.

---

## How an e-commerce business benefits

For an online marketplace like Olist, data moves fast: thousands of orders, payments, reviews, and seller interactions per day. This platform delivers structured, reliable analytics that directly support business decisions:

| Business question | Mart / metric that answers it |
|---|---|
| Is daily revenue growing or declining? | `mrt_daily_sales.gross_merchandise_value` |
| Which sellers are driving the most volume and satisfaction? | `mrt_seller_performance.total_orders` + `avg_review_score` |
| Are remote states suffering worse delivery times? | `mrt_state_sales.avg_delivery_days` |
| How does freight cost compare to product revenue by day? | `mrt_daily_sales.gross_item_revenue` vs `total_freight` |
| Which days had CSAT spikes that correlate with delivery issues? | `mrt_daily_sales.avg_review_score` vs `avg_delivery_days` |

Having this data refreshed daily and ready in BigQuery means executives, operations managers, and marketing teams can query it directly from Looker Studio, Metabase, or any BI tool—without waiting for an analyst to run a manual report.

---

## Architecture

```
Kaggle (CSV files)
       │  kagglehub download
       ▼
  GCS Staging Bucket   ←── dlt stages Parquet files here
       │  BigQuery bulk LOAD job
       ▼
 BigQuery: raw_olist_data  (raw tables, untouched)
       │  dbt build
       ▼
 BigQuery: olist_analytics_staging      (typed views)
       │
       ▼
 BigQuery: olist_analytics_intermediate (wide joined table)
       │
       ▼
 BigQuery: olist_analytics_marts        (aggregated fact tables)
       │
       ▼
   BI Tools (Looker Studio, Metabase, etc.)
```

All steps are orchestrated by Dagster and run on a daily schedule at 02:00 Madrid time.

---

## Transformation design

### Layer 1 — Staging (views)

Each staging model is a 1:1 type-cast of a raw BigQuery table. No business logic lives here—just explicit `CAST()` expressions to enforce correct types (timestamps, numerics, strings) and column renames to fix upstream typos. Materialised as **views** so they always reflect the latest raw data without duplicating storage.

Key staging models:

| Model | Source table | Primary key |
|---|---|---|
| `stg_orders` | `olist_orders_dataset` | `order_id` |
| `stg_order_items` | `olist_order_items_dataset` | `order_id` + `order_item_id` |
| `stg_order_payments` | `olist_order_payments_dataset` | `order_id` + `payment_sequential` |
| `stg_customers` | `olist_customers_dataset` | `customer_id` |
| `stg_products` | `olist_products_dataset` | `product_id` |
| `stg_sellers` | `olist_sellers_dataset` | `seller_id` |
| `stg_reviews` | `olist_order_reviews_dataset` | `review_id` |
| `stg_category_translation` | `product_category_name_translation` | `product_category_name` |

### Layer 2 — Intermediate (table)

**`int_order_enriched`** is a single wide, denormalised table that joins all eight staging models onto the order + order-item grain. Every mart reads from this one model, which means the expensive multi-table join is computed once and persisted as a BigQuery table. Key derived column: `delivery_days` (integer elapsed days from purchase to delivery), used by all three marts.

Grain: **one row per order + order item** (i.e. per product line within an order).

### Layer 3 — Marts (tables)

Marts are the final, aggregated tables exposed to BI tools. Each one is designed around a specific analytical question.

#### `mrt_daily_sales`
**Grain:** one row per calendar date.

**Why this mart:** The most fundamental time-series view of the business. Operations and finance teams need a daily pulse on order volume, revenue, freight cost, and customer satisfaction. This table powers trend dashboards, anomaly detection, and period-over-period comparisons (WoW, MoM, YoY).

**Metrics:** `total_orders`, `total_items`, `gross_item_revenue`, `total_freight`, `gross_merchandise_value` (GMV = product + freight), `avg_review_score`, `avg_delivery_days`.

#### `mrt_seller_performance`
**Grain:** one row per seller (all-time cumulative).

**Why this mart:** Olist operates as a marketplace—the platform's reputation depends entirely on seller quality. This mart powers seller scorecards that the operations team can use to identify: (a) top sellers eligible for promotional placement or incentive programmes; (b) underperforming sellers with low review scores or slow delivery who need intervention or removal. The `seller_state` dimension also reveals geographic clusters of high/low-performing sellers, informing regional seller acquisition strategy.

**Metrics:** `total_orders`, `total_item_revenue`, `total_freight_value`, `avg_review_score`, `avg_delivery_days`.

#### `mrt_state_sales`
**Grain:** one row per Brazilian state (all-time cumulative).

**Why this mart:** Brazil is a continent-sized country with enormous logistics complexity. Delivery times from São Paulo fulfilment hubs to northern states like Amazonas or Pará can exceed 20 days, directly depressing review scores. This mart surfaces: (a) which states generate the most revenue (prioritise warehouse placement / carrier negotiations); (b) which states have the highest average delivery days (identify logistics gaps); (c) whether GMV and satisfaction correlate at state level (find under-served high-potential markets). These insights directly feed supply chain, marketing spend allocation, and expansion planning decisions.

**Metrics:** `total_orders`, `gross_merchandise_value`, `avg_review_score`, `avg_delivery_days`.

---

## Scalability possibilities

The current architecture handles the full Olist historical dataset (~100k orders) in a single daily run. The design choices made here make it straightforward to scale in several directions:

### Data volume
- **Partitioned & clustered BigQuery tables:** Add `partition_by` and `cluster_by` to `int_order_enriched` and the mart models in `dbt_project.yml`. BigQuery will only scan the partitions relevant to each query, cutting costs dramatically for large tables.
- **Incremental dbt models:** Replace `materialized: table` with `materialized: incremental` in the intermediate and mart models, keyed on `order_purchase_timestamp`. Only new/changed rows are processed on each run, reducing build time from O(total rows) to O(new rows per day).
- **Streaming ingestion:** Swap the `WRITE_DISPOSITION=replace` strategy in `run.py` for `append` or `merge` and replace kagglehub with a real-time Kafka or Pub/Sub consumer. dlt supports both.

### Data sources
- **New source tables:** Add a new staging model + source entry in `sources.yml`. The intermediate layer can be extended with additional LEFT JOINs without touching any mart logic.
- **Multiple datasets:** The dbt project structure (staging/intermediate/marts) scales to any number of source systems. Add a new `sources.yml` per source and a new staging subfolder.

### Orchestration
- **Dagster Assets:** Migrate from `@op`/`@job` to `@asset` definitions. Asset-based orchestration enables fine-grained dependency tracking, partial re-materialisation, and freshness policies per table rather than per job.
- **Dagster sensors:** Add a GCS sensor that triggers the pipeline when new data files land in the staging bucket, instead of running on a fixed cron schedule.
- **Parallel dbt execution:** Increase `threads` in `profiles.yml` to build independent staging models concurrently.

### Infrastructure
- **Cloud Run Jobs:** Package the ingestion container as a Cloud Run Job triggered by Cloud Scheduler. This removes the need to keep a long-running VM or daemon process alive.
- **Terraform remote state:** Add a GCS backend block to `providers.tf` so Terraform state is stored centrally and shared across team members.
- **Multiple environments:** Duplicate `infra/envs/dev/` to `infra/envs/prod/` with production-grade settings (larger BigQuery slots reservation, versioned GCS bucket, VPC Service Controls).
- **CI/CD deployment:** Extend `.github/workflows/ci.yml` to build and push the Docker image to Artifact Registry on merge to `main`, then trigger a Cloud Run Job or redeploy the Dagster daemon automatically.

---

## Repository layout

| Path | Description |
|---|---|
| `ingestion/` | Kaggle-to-BigQuery dlt pipeline |
| `transform/` | dbt Core project (staging, intermediate, marts) |
| `dagster_orchestration/` | Dagster job, ops, and schedule definitions |
| `infra/` | Terraform configuration for GCP resources |
| `docs/` | Runbook and data dictionary |
| `Dockerfile` | Single image for all services |
| `docker-compose.yml` | Local multi-service runtime |

---

## Quick start

Follow [docs/step-by-step.md](docs/step-by-step.md) for the full walkthrough.

Additional references:
- [docs/data-dictionary.md](docs/data-dictionary.md)
- [infra/README.md](infra/README.md)

---

## Docker

```bash
# Build the image
docker compose build

# Run one ingestion execution
docker compose run --rm ingestion

# Start Dagster UI + daemon
docker compose up dagster-webserver dagster-daemon
```

Configure `.env` (copy from `.env.example`) and ensure `GOOGLE_APPLICATION_CREDENTIALS` is mounted before running containers.

---

## Common commands

```bash
# Install all dependencies
pip install -r requirements.txt

# Run ingestion once (local)
python -m ingestion.pipeline.run

# Build all dbt models and run tests
cd transform
dbt deps
dbt build --profiles-dir .

# Start Dagster local UI (http://localhost:3000)
cd ..
dg dev -m dagster_orchestration.jobs.definitions
```

---

## CI

`.github/workflows/ci.yml` runs on every push:
- Python import smoke tests
- dbt dependency resolution (`dbt deps`)
- dbt parse check (`dbt parse`)

---

## Security

- Do not commit credentials, `.env`, `profiles.yml`, or service account key files.
- Use environment variables or GCP Secret Manager for all secrets.
- Example values are provided in `.env.example` and `terraform.tfvars.example`.

---

## Reproducibility

To reproduce this pipeline from scratch:
1. Provision GCP infrastructure: `cd infra/envs/dev && terraform apply`
2. Copy `.env.example` → `.env` and fill in all values (see inline comments in each file for which variables to change).
3. Copy `transform/profiles.yml.example` → `transform/profiles.yml` and fill in your project/credentials.
4. Run `python -m ingestion.pipeline.run` to load raw data.
5. Run `cd transform && dbt deps && dbt build --profiles-dir .` to build all models.
6. Start Dagster: `dg dev -m dagster_orchestration.jobs.definitions`.

