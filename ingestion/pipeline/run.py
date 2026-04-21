# =============================================================================
# ingestion/pipeline/run.py
#
# Purpose:
#   Downloads the Olist Brazilian E-commerce dataset from Kaggle, loads each CSV
#   into memory as a pandas DataFrame, and then uses dlt (data load tool) to
#   write every table into BigQuery.  Optionally stages data through GCS first
#   (DLT_LOAD_MODE=staged) which is recommended for large payloads because it
#   avoids the BigQuery streaming quota and uses bulk-load instead.
#
# Why we need it:
#   Raw data lives on Kaggle as static CSV files.  This script is the "Extract"
#   and "Load" step of the ELT pipeline.  Without it, dbt has nothing to
#   transform and Dagster has nothing to orchestrate.
#
# Reproducibility – variables that MUST be changed:
#   GCP_PROJECT_ID          → your GCP project ID (required)
#   BQ_RAW_DATASET          → BigQuery dataset for raw tables (default: raw_olist_data)
#   BQ_LOCATION             → BigQuery/GCS region (default: europe-southwest1)
#   DLT_STAGING_BUCKET_URL  → gs://your-bucket-name  (required when DLT_LOAD_MODE=staged)
#   KAGGLE_USERNAME / KAGGLE_KEY  → Kaggle API credentials (or KAGGLE_API_TOKEN)
#   WRITE_DISPOSITION       → replace | append | merge  (default: replace)
# =============================================================================

import os
from pathlib import Path
from typing import Dict, List

import dlt
import kagglehub
import pandas as pd

# Kaggle dataset identifier – change this if you fork to a different dataset.
DATASET_REF = "olistbr/brazilian-ecommerce"
# Explicit list of files we expect inside the downloaded archive.
# If Kaggle ever renames a file, update the relevant entry here.
EXPECTED_FILES = [
    "olist_customers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]


def _required_env(name: str) -> str:
    """Read a mandatory environment variable; raise clearly if it is absent."""
    value = os.getenv(name, "").strip()
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def _optional_env(name: str, default: str) -> str:
    """Read an optional environment variable, falling back to *default*."""
    value = os.getenv(name)
    return value.strip() if value else default


def _validate_kaggle_auth() -> None:
    """Ensure Kaggle credentials are present before attempting a download."""
    has_pair = bool(os.getenv("KAGGLE_USERNAME")) and bool(os.getenv("KAGGLE_KEY"))
    has_token = bool(os.getenv("KAGGLE_API_TOKEN"))
    if not (has_pair or has_token):
        raise ValueError(
            "Kaggle credentials are missing. Set KAGGLE_USERNAME/KAGGLE_KEY or KAGGLE_API_TOKEN."
        )


def _resolve_dataset_dir() -> Path:
    """Download the Olist dataset from Kaggle and return the local directory.

    kagglehub caches downloads so subsequent runs are instant unless the
    dataset version changes on Kaggle.
    """
    _validate_kaggle_auth()
    dataset_path = kagglehub.dataset_download(DATASET_REF)
    path = Path(dataset_path)
    if not path.exists():
        raise FileNotFoundError(f"Dataset path not found: {dataset_path}")
    return path


def _find_csv_files(dataset_dir: Path) -> List[Path]:
    """Return the ordered list of CSV files we want to load.

    Tries EXPECTED_FILES first so table names are deterministic.  Falls back
    to a glob so the pipeline degrades gracefully if Kaggle adds new files.
    """
    files: List[Path] = []
    for file_name in EXPECTED_FILES:
        candidate = dataset_dir / file_name
        if candidate.exists():
            files.append(candidate)
    if not files:
        files = sorted(dataset_dir.rglob("*.csv"))
    if not files:
        raise FileNotFoundError("No CSV files found in downloaded Olist dataset")
    return files


def _load_frames(csv_files: List[Path]) -> Dict[str, pd.DataFrame]:
    """Read each CSV into a pandas DataFrame, normalising column names to
    lowercase so dlt and BigQuery receive consistent identifiers.
    The file stem (e.g. 'olist_orders_dataset') becomes the BigQuery table name.
    """
    frames: Dict[str, pd.DataFrame] = {}
    for csv_file in csv_files:
        table_name = csv_file.stem.lower()
        df = pd.read_csv(csv_file, low_memory=False)
        df.columns = [c.strip().lower() for c in df.columns]
        frames[table_name] = df
    return frames


def run() -> None:
    """Entry point executed by Dagster (via `python -m ingestion.pipeline.run`)
    and by the Docker ingestion service.

    Steps:
      1. Read and validate all required environment variables.
      2. Configure dlt pipeline (destination=BigQuery, optional staging=GCS).
      3. Download the Olist dataset from Kaggle.
      4. Load every CSV as a dlt resource into BigQuery.
    """
    # CHANGE THIS: must match your GCP project ID
    gcp_project_id = _required_env("GCP_PROJECT_ID")
    # CHANGE THIS if you want a different BigQuery dataset name for raw tables
    raw_dataset = _optional_env("BQ_RAW_DATASET", "raw_olist_data")
    # 'replace' drops and recreates the table on every run – safe for a static
    # historical dataset.  Switch to 'append' or 'merge' for live event streams.
    write_disposition = _optional_env("WRITE_DISPOSITION", "replace")
    pipeline_name = _optional_env("DLT_PIPELINE_NAME", "olist_ecommerce_ingestion")
    # CHANGE THIS if your GCP resources are in a different region
    bq_location = _optional_env("BQ_LOCATION", "europe-southwest1")
    # 'staged' = write to GCS first, then bulk-load into BigQuery (recommended).
    # Set to 'direct' to skip GCS staging (requires less IAM but slower for large files).
    dlt_load_mode = _optional_env("DLT_LOAD_MODE", "staged").lower()
    # CHANGE THIS: gs://your-bucket-name – must match the Terraform-created bucket
    staging_bucket = os.getenv("DLT_STAGING_BUCKET_URL", "").strip()

    # Pass BigQuery location to dlt via environment so it applies to all destinations
    os.environ.setdefault("DESTINATION__BIGQUERY__LOCATION", bq_location)

    # Base dlt pipeline configuration
    pipeline_kwargs = {
        "pipeline_name": pipeline_name,
        "destination": "bigquery",
        "dataset_name": raw_dataset,
    }

    # When staged mode is enabled, dlt writes Parquet files to GCS then issues a
    # BigQuery LOAD job \u2013 far more efficient than row-by-row streaming inserts.
    if dlt_load_mode == "staged":
        if not staging_bucket:
            raise ValueError("DLT_STAGING_BUCKET_URL is required when DLT_LOAD_MODE=staged")
        os.environ.setdefault("DESTINATION__FILESYSTEM__BUCKET_URL", staging_bucket)
        pipeline_kwargs["staging"] = "filesystem"

    dataset_dir = _resolve_dataset_dir()
    csv_files = _find_csv_files(dataset_dir)
    frames = _load_frames(csv_files)

    pipeline = dlt.pipeline(**pipeline_kwargs)

    # Load each DataFrame as a separate BigQuery table.
    # dlt infers the schema from pandas dtypes and auto-creates the tables.
    summary = []
    for table_name, df in frames.items():
        records = df.to_dict(orient="records")
        resource = dlt.resource(records, name=table_name, write_disposition=write_disposition)
        load_info = pipeline.run(resource)
        summary.append((table_name, len(df), str(load_info)))

    print("Ingestion completed")
    print(f"Project: {gcp_project_id}")
    print(f"Dataset: {raw_dataset}")
    print(f"Location: {bq_location}")
    print(f"Pipeline: {pipeline_name}")
    print(f"Load mode: {dlt_load_mode}")
    for table_name, row_count, _ in summary:
        print(f"- {table_name}: {row_count} rows")


if __name__ == "__main__":
    run()
