# Step-by-Step Reproducibility Guide

This guide rebuilds the project from zero in your own GCP environment and mirrors the root README runbook.

## 1) Clone repo and create virtual environment

```bash
git clone https://github.com/tangybluff/olist-ecommerce-orchestrator.git
cd olist-ecommerce-orchestrator
python -m venv .venv
source .venv/Scripts/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 2) Authenticate GCP using ADC (recommended)

```bash
gcloud auth login
gcloud config set project YOUR_GCP_PROJECT_ID
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_GCP_PROJECT_ID
```

Replace:
- `YOUR_GCP_PROJECT_ID` with your project id.

## 3) Configure and apply Terraform

```bash
cp infra/envs/dev/terraform.tfvars.example infra/envs/dev/terraform.tfvars
cd infra/envs/dev
terraform init
terraform apply -auto-approve
cd ../../..
```

Edit `infra/envs/dev/terraform.tfvars` before apply:
- `gcp_project_id`
- `gcp_region`
- `raw_dataset_id`
- `analytics_dataset_base`
- `staging_bucket_name` (must be globally unique)

## 4) Configure runtime environment

```bash
cp .env.example .env
```

Edit `.env` and set:
- `GCP_PROJECT_ID`
- `BQ_RAW_DATASET`
- `BQ_DBT_DATASET`
- `BQ_LOCATION`
- `DLT_PIPELINE_NAME`
- `DLT_LOAD_MODE=staged`
- `DLT_STAGING_BUCKET_URL=gs://YOUR_BUCKET_NAME`
- `WRITE_DISPOSITION=replace`
- `KAGGLE_USERNAME`
- `KAGGLE_KEY`
- `DBT_PROFILES_DIR=transform`

## 5) Configure dbt profile

```bash
cp transform/profiles.yml.example transform/profiles.yml
```

Edit `transform/profiles.yml`:
- `project`: your GCP project id
- `dataset`: keep env-var pattern via `BQ_DBT_DATASET`
- `location`: keep env-var pattern via `BQ_LOCATION`
- `method`: set to `oauth` when using ADC

## 6) Run ingestion (Kaggle -> BigQuery raw)

```bash
set -a && source .env && set +a
python -m ingestion.pipeline.run
```

Expected outcome:
- Log includes `Ingestion completed`
- Nine raw tables exist in your raw dataset

## 7) Run dbt transformations

```bash
cd transform
dbt deps --profiles-dir .
dbt build --profiles-dir .
cd ..
```

Expected outcome:
- dbt summary like `PASS=28 WARN=0 ERROR=0`
- Marts created in `<BQ_DBT_DATASET>_marts`

## 8) Verify marts in BigQuery

```bash
bq ls --project_id=YOUR_GCP_PROJECT_ID YOUR_GCP_PROJECT_ID:<BQ_DBT_DATASET>_marts
```

Expected tables:
- `mrt_daily_sales`
- `mrt_seller_performance`
- `mrt_state_sales`

## 9) Run Dagster locally (optional)

```bash
dg dev -m dagster_orchestration.jobs.definitions
```

In Dagster UI:
- Run `daily_olist_pipeline`
- Confirm `daily_schedule` is available

## 10) Run with Docker (optional)

```bash
docker compose build
docker compose run --rm ingestion
docker compose up dagster-webserver dagster-daemon
```

Notes:
- Ensure `.env` exists before running containers.
- Do not bake secrets into images.

## 11) Validation checklist

- Ingestion created expected raw tables.
- dbt build completed successfully.
- Marts contain rows.
- Dagster can run ingestion and dbt in sequence.

