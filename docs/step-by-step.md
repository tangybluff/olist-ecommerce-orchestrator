# Step-by-Step Reproducibility Guide

This guide walks from zero to a daily orchestrated Olist data pipeline.

## 1) Create and activate virtual environment

```bash
# Clone repo to whatever local folder you want
cd "C:/Users/.../Downloads"
cd olist-ecommerce-orchestrator
python -m venv .venv
source .venv/Scripts/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 2) Prepare credentials securely

Do not hardcode credentials in source files.

### Kaggle

Option A: environment variables

```bash
export KAGGLE_USERNAME="your_username"
export KAGGLE_KEY="your_key"
```

Option B: Kaggle credentials file

- Create `~/.kaggle/kaggle.json`
- Restrict permissions as needed by your OS.

### GCP

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/service-account.json"
export GCP_PROJECT_ID="your-gcp-project-id"
export BQ_LOCATION="europe-southwest1"
```

## 3) Provision cloud resources

```bash
cd infra/envs/dev
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your values
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
cd ../../..
```

## 4) Configure pipeline environment

```bash
cp .env.example .env
# edit .env values
export BQ_RAW_DATASET="raw_olist_data"
export BQ_DBT_DATASET="olist_analytics"
export DLT_PIPELINE_NAME="olist_ecommerce_ingestion"
export DLT_LOAD_MODE="staged"
export DLT_STAGING_BUCKET_URL="gs://your-olist-staging-bucket"
export WRITE_DISPOSITION="replace"
```

## 5) Run ingestion (Kaggle -> BigQuery raw)

```bash
python -m ingestion.pipeline.run
```

Expected outcome:

- Raw Olist tables loaded into BigQuery dataset `raw_olist_data`
- Only source data from the Olist Kaggle dataset is used

## 6) Configure dbt profile

```bash
cd transform
cp profiles.yml.example profiles.yml
```

Ensure required environment variables are exported.

## 7) Run dbt transformations

```bash
dbt deps --profiles-dir .
dbt build --profiles-dir .
```

Expected outcome:

- `staging`, `intermediate`, and `marts` schemas created under analytics dataset
- dbt tests pass

## 8) Run Dagster locally

```bash
cd ..
dg dev -m dagster_orchestration.jobs.definitions
```

In Dagster UI:

- Run `daily_olist_pipeline` manually to validate orchestration.
- Confirm schedule `daily_schedule` is active for daily runs.

## 9) Run with Docker (optional)

```bash
docker compose build
docker compose run --rm ingestion
docker compose up dagster-webserver dagster-daemon
```

Notes:

- Ensure `.env` exists and contains your non-secret configuration values.
- Do not bake secrets into images.
- Mount service-account credentials as read-only files when needed.

## 10) CI validation

GitHub Actions CI (`.github/workflows/ci.yml`) validates:

- Python module import integrity
- dbt dependency resolution
- dbt parse

Run equivalent checks locally before push:

```bash
python -m compileall ingestion dagster_orchestration
python -c "from ingestion.pipeline.run import run"
python -c "from dagster_orchestration.jobs.definitions import defs"
cd transform
dbt deps --profiles-dir .
dbt parse --profiles-dir .
```

## 11) Production notes

- Use Secret Manager or equivalent for credentials.
- Run Dagster daemon and webserver in a managed runtime.
- Keep location baseline `europe-southwest1` unless a required service is unavailable.

## 12) Validation checklist

- Ingestion creates expected raw tables.
- dbt build finishes successfully.
- Marts tables contain rows.
- Dagster can run ingestion and dbt in sequence.

