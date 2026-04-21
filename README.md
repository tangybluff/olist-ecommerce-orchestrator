# Olist E-commerce Data Platform

End-to-end data platform for the Olist Brazilian e-commerce dataset using:

- Ingestion: Python + kagglehub + dlt
- Storage path: Kaggle -> GCS staging bucket -> BigQuery raw dataset
- Transformations: dbt Core (staging, intermediate, marts)
- Orchestration: Dagster daily schedule


## Architecture

1. Download Olist dataset from Kaggle using `kagglehub`.
2. Load raw CSV files into BigQuery with dlt.
3. Build analytics models in dbt.
4. Orchestrate ingestion and dbt with Dagster on a daily schedule.

## Repository Layout

- `ingestion/`: Kaggle-to-BigQuery dlt pipeline
- `transform/`: dbt Core project for modeling
- `dagster_orchestration/`: Dagster jobs and schedule definitions
- `infra/`: Terraform baseline for GCP resources
- `docs/`: runbook and data dictionary
- `.github/workflows/`: CI workflow
- `Dockerfile` and `docker-compose.yml`: minimal containerized runtime

## Quick Start

Follow [docs/step-by-step.md](docs/step-by-step.md).

Additional references:

- [docs/data-dictionary.md](docs/data-dictionary.md)
- [infra/README.md](infra/README.md)

## Docker

Minimal Docker support is included:

- `Dockerfile` for the project runtime
- `docker-compose.yml` with services for ingestion, Dagster webserver, and Dagster daemon

Example commands:

```bash
# Build images
docker compose build

# Run one ingestion execution
docker compose run --rm ingestion

# Start Dagster UI + daemon
docker compose up dagster-webserver dagster-daemon
```

Before running containers, configure `.env` and ensure `GOOGLE_APPLICATION_CREDENTIALS` is mounted into containers.

## CI

Minimal CI is included in `.github/workflows/ci.yml` and runs:

- Python import smoke tests
- dbt dependency resolution
- dbt parse checks

## Security

- Do not commit credentials.
- Use environment variables or secret managers.
- Example variables are provided in `.env.example`.

## Reproducibility

For reproducibility, follow `docs/step-by-step.md` exactly and fill in:

- Your filled non-secret config values (project IDs, dataset names, bucket names)
- The command outputs from ingestion, dbt build, and Dagster job run

## Common Commands

```bash
# Install dependencies
pip install -r requirements.txt

# Run ingestion once
python -m ingestion.pipeline.run

# Build dbt models
cd transform
dbt deps
dbt build --profiles-dir .

# Start Dagster local UI
cd ..
dg dev -m dagster_orchestration.jobs.definitions
```

Dagster orchestrates both ingestion and dbt transformations in one daily scheduled job.
