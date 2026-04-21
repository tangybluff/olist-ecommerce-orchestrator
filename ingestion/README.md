# Ingestion

This module downloads the Olist Kaggle dataset and loads raw tables into BigQuery using dlt.

## Required Environment Variables

- `GCP_PROJECT_ID`
- `GOOGLE_APPLICATION_CREDENTIALS`
- `KAGGLE_USERNAME` and `KAGGLE_KEY` (or `KAGGLE_API_TOKEN`)

## Optional Environment Variables

- `BQ_RAW_DATASET` (default: `raw_olist_data`)
- `BQ_LOCATION` (default: `europe-southwest1`)
- `DLT_PIPELINE_NAME` (default: `olist_ecommerce_ingestion`)
- `DLT_LOAD_MODE` (`staged` or `direct`, default: `staged`)
- `DLT_STAGING_BUCKET_URL` (required if staged mode)
- `WRITE_DISPOSITION` (`replace`, `append`, or `merge`, default: `replace`)

## Run

```bash
python -m ingestion.pipeline.run
```
