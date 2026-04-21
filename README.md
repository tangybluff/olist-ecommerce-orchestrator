# Olist E-commerce Data Platform

## Objective

Build a fully automated, cloud-native ELT pipeline that ingests the Olist Brazilian e-commerce dataset from Kaggle into Google BigQuery, transforms it into analytics-ready tables using dbt, and surfaces key business metrics in a Looker Studio dashboard — all orchestrated end-to-end by Dagster on a daily schedule and provisioned with Terraform.

## Problem Statement

E-commerce marketplaces generate raw transactional data across many systems — orders, payments, logistics, customer reviews, and seller records — that is scattered, untyped, and unsuitable for direct analysis. Analysts relying on raw exports face inconsistent data types, missing join keys, and no repeatable transformation logic, leading to ad-hoc queries, duplicated business logic across spreadsheets, and metrics that cannot be trusted.

This project solves that by building a structured ELT platform on top of the Olist dataset, a real Brazilian marketplace with ~100k orders across 2016–2018. The pipeline:

- Loads all nine raw CSV files into BigQuery as a versioned, immutable raw layer.
- Applies consistent typing, joins, and aggregations in dbt to produce a set of mart tables that answer the three most operationally important questions for an e-commerce business: **daily sales trends**, **seller quality**, and **regional logistics performance**.
- Runs automatically every day via a Dagster schedule so metrics are always fresh.

**Pipeline type: Batch.** Data is ingested and transformed once per day on a scheduled trigger (not a streaming or event-driven architecture).

---

## Technology stack

- **Ingestion:** Python + kagglehub + dlt (Kaggle → GCS → BigQuery)
- **Transformation:** dbt Core (staging → intermediate → marts)
- **Orchestration:** Dagster daily schedule
- **Infrastructure:** Terraform on GCP (GCS, BigQuery, Secret Manager)
- **Containerisation:** Docker / Docker Compose
- **Dashboard:** Looker Studio (connected to BigQuery mart tables)

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

---

## Dashboard

The dashboard is built in **Looker Studio** connected directly to the BigQuery mart tables. It contains two tiles that satisfy the categorical and temporal distribution requirements.

### Tile 1 — Gross Merchandise Value over Time (temporal)

**Chart type:** Time series / Line chart  
**Data source:** `mrt_daily_sales`  
**X-axis:** `order_date`  
**Y-axis:** `gross_merchandise_value`  
**Secondary metric:** `avg_review_score` (right axis)  
**Title:** "Daily GMV and Average Customer Satisfaction"

This tile shows how total daily revenue (product price + freight) evolves over the dataset period (2016–2018), making it easy to spot seasonal peaks, promotional spikes, and the platform's overall growth trajectory. Overlaying the average review score reveals whether high-volume periods coincide with lower satisfaction — a common pattern during peak seasons when delivery capacity is stretched.

### Tile 2 — Orders by Brazilian State (categorical)

**Chart type:** Bar chart (sorted descending) or geo map of Brazil  
**Data source:** `mrt_state_sales`  
**Dimension:** `customer_state`  
**Metrics:** `total_orders`, `gross_merchandise_value`, `avg_delivery_days`  
**Title:** "Order Volume and Average Delivery Days by State"

This tile shows the distribution of orders across Brazil's 27 states, exposing the strong São Paulo concentration and the logistics gap faced by northern/north-eastern states. Adding `avg_delivery_days` as a colour-coded secondary metric immediately highlights which states are under-served by the current fulfilment network.

### How to create the dashboard

1. Open [Looker Studio](https://lookerstudio.google.com) and create a new report.
2. Add a **BigQuery** data source; select your GCP project → `olist_analytics_marts` dataset.
3. Add `mrt_daily_sales` as the first data source and create a **Time series** chart with `order_date` as the dimension and `gross_merchandise_value` as the metric.
4. Add `mrt_state_sales` as a second data source and create a **Bar chart** with `customer_state` as the dimension and `total_orders` as the metric, sorted descending.
5. Add titles, axis labels, and a date range control for filtering.

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

## Security

- Do not commit credentials, `.env`, `profiles.yml`, or service account key files.
- Use environment variables or GCP Secret Manager for all secrets.
- Example values are provided in `.env.example` and `terraform.tfvars.example`.

---

## Reproducibility

Use this section to rebuild the full platform in your own GCP project from zero.

### Step 0 - Prerequisites

Install and verify:
- Python 3.12+
- Google Cloud CLI
- Terraform 1.14+
- A Kaggle account and API key

Run:

```bash
python --version
gcloud --version
terraform --version
```

### Step 1 - Clone the project

```bash
git clone https://github.com/tangybluff/olist-ecommerce-orchestrator.git
cd olist-ecommerce-orchestrator
```

Files you will edit in the next steps:
- `infra/envs/dev/terraform.tfvars`
- `.env`
- `transform/profiles.yml`

### Step 2 - Create your own GCP project context

Set your project and authenticate Application Default Credentials (ADC):

```bash
gcloud auth login
gcloud config set project YOUR_GCP_PROJECT_ID
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_GCP_PROJECT_ID
```

Replace:
- `YOUR_GCP_PROJECT_ID` with your real project id (example: `my-de-project-123`).

### Step 3 - Configure Terraform variables

Create your Terraform variables file:

```bash
cp infra/envs/dev/terraform.tfvars.example infra/envs/dev/terraform.tfvars
```

Edit `infra/envs/dev/terraform.tfvars` and update:
- `gcp_project_id` -> your project id
- `gcp_region` -> your preferred region (example: `europe-southwest1`)
- `raw_dataset_id` -> raw dataset name (example: `raw_olist_data`)
- `analytics_dataset_base` -> analytics base name (example: `olist_analytics`)
- `staging_bucket_name` -> globally unique bucket name

### Step 4 - Provision cloud infrastructure

```bash
cd infra/envs/dev
terraform init
terraform apply -auto-approve
cd ../../..
```

Expected resources:
- One GCS staging bucket
- One raw BigQuery dataset
- One analytics BigQuery dataset base (dbt will create suffixed datasets)

### Step 5 - Configure runtime environment variables

Create local env file:

```bash
cp .env.example .env
```

Edit `.env` and update these values:
- `GCP_PROJECT_ID=YOUR_GCP_PROJECT_ID`
- `BQ_RAW_DATASET=YOUR_RAW_DATASET` (must match Terraform raw dataset)
- `BQ_DBT_DATASET=YOUR_ANALYTICS_BASE` (must match Terraform analytics base)
- `BQ_LOCATION=YOUR_BQ_LOCATION` (must match dataset location)
- `DLT_PIPELINE_NAME=YOUR_PIPELINE_NAME` (any stable name)
- `DLT_LOAD_MODE=staged`
- `DLT_STAGING_BUCKET_URL=gs://YOUR_STAGING_BUCKET_NAME`
- `WRITE_DISPOSITION=replace` (or `append` for different behavior)
- `KAGGLE_USERNAME=YOUR_KAGGLE_USERNAME`
- `KAGGLE_KEY=YOUR_KAGGLE_KEY`
- `DBT_PROFILES_DIR=transform`

### Step 6 - Configure dbt BigQuery profile

Create profile file:

```bash
cp transform/profiles.yml.example transform/profiles.yml
```

Edit `transform/profiles.yml` and set:
- `project` -> your GCP project id
- `dataset` -> `{{ env_var('BQ_DBT_DATASET', 'olist_analytics') }}` (keep env-var pattern)
- `location` -> `{{ env_var('BQ_LOCATION', 'europe-southwest1') }}`
- auth method: use `method: oauth` if using ADC (recommended local setup)
- use service-account method only if you explicitly manage key files

### Step 7 - Install Python dependencies

```bash
pip install -r requirements.txt
```

If you see dependency warnings but installation completes, continue unless there is a hard error.

### Step 8 - Run ingestion (Kaggle -> BigQuery raw)

```bash
set -a && source .env && set +a
python -m ingestion.pipeline.run
```

Expected result:
- Log line containing `Ingestion completed`
- Nine raw tables loaded in your raw dataset

### Step 9 - Run dbt transformations and tests

```bash
cd transform
dbt deps --profiles-dir .
dbt build --profiles-dir .
cd ..
```

Expected result:
- dbt summary similar to: `PASS=28 WARN=0 ERROR=0`
- Final marts created in dataset: `<BQ_DBT_DATASET>_marts`

### Step 10 - Verify output tables in BigQuery

```bash
bq ls --project_id=YOUR_GCP_PROJECT_ID YOUR_GCP_PROJECT_ID:<BQ_DBT_DATASET>_marts
```

You should see:
- `mrt_daily_sales`
- `mrt_seller_performance`
- `mrt_state_sales`

### Step 11 - Run orchestration locally (optional)

```bash
dg dev -m dagster_orchestration.jobs.definitions
```

Open Dagster UI at `http://localhost:3000` and trigger `daily_olist_pipeline`.

### Common file map (what to change vs keep)

Change values:
- `.env`
- `transform/profiles.yml`
- `infra/envs/dev/terraform.tfvars`

Usually keep as-is:
- `ingestion/pipeline/run.py`
- `transform/models/*`
- `dagster_orchestration/jobs/definitions.py`

### Security checklist

- Never commit `.env`, `terraform.tfvars`, or credential files.
- Keep only examples in git: `.env.example`, `terraform.tfvars.example`, `profiles.yml.example`.

