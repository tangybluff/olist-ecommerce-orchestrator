import os
from pathlib import Path
from typing import Dict, List

import dlt
import kagglehub
import pandas as pd

DATASET_REF = "olistbr/brazilian-ecommerce"
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
    value = os.getenv(name, "").strip()
    if not value:
        raise ValueError(f"Missing required environment variable: {name}")
    return value


def _optional_env(name: str, default: str) -> str:
    value = os.getenv(name)
    return value.strip() if value else default


def _validate_kaggle_auth() -> None:
    has_pair = bool(os.getenv("KAGGLE_USERNAME")) and bool(os.getenv("KAGGLE_KEY"))
    has_token = bool(os.getenv("KAGGLE_API_TOKEN"))
    if not (has_pair or has_token):
        raise ValueError(
            "Kaggle credentials are missing. Set KAGGLE_USERNAME/KAGGLE_KEY or KAGGLE_API_TOKEN."
        )


def _resolve_dataset_dir() -> Path:
    _validate_kaggle_auth()
    dataset_path = kagglehub.dataset_download(DATASET_REF)
    path = Path(dataset_path)
    if not path.exists():
        raise FileNotFoundError(f"Dataset path not found: {dataset_path}")
    return path


def _find_csv_files(dataset_dir: Path) -> List[Path]:
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
    frames: Dict[str, pd.DataFrame] = {}
    for csv_file in csv_files:
        table_name = csv_file.stem.lower()
        df = pd.read_csv(csv_file, low_memory=False)
        df.columns = [c.strip().lower() for c in df.columns]
        frames[table_name] = df
    return frames


def run() -> None:
    gcp_project_id = _required_env("GCP_PROJECT_ID")
    raw_dataset = _optional_env("BQ_RAW_DATASET", "raw_olist_data")
    write_disposition = _optional_env("WRITE_DISPOSITION", "replace")
    pipeline_name = _optional_env("DLT_PIPELINE_NAME", "olist_ecommerce_ingestion")
    bq_location = _optional_env("BQ_LOCATION", "europe-southwest1")
    dlt_load_mode = _optional_env("DLT_LOAD_MODE", "staged").lower()
    staging_bucket = os.getenv("DLT_STAGING_BUCKET_URL", "").strip()

    os.environ.setdefault("DESTINATION__BIGQUERY__LOCATION", bq_location)

    pipeline_kwargs = {
        "pipeline_name": pipeline_name,
        "destination": "bigquery",
        "dataset_name": raw_dataset,
    }

    if dlt_load_mode == "staged":
        if not staging_bucket:
            raise ValueError("DLT_STAGING_BUCKET_URL is required when DLT_LOAD_MODE=staged")
        os.environ.setdefault("DESTINATION__FILESYSTEM__BUCKET_URL", staging_bucket)
        pipeline_kwargs["staging"] = "filesystem"

    dataset_dir = _resolve_dataset_dir()
    csv_files = _find_csv_files(dataset_dir)
    frames = _load_frames(csv_files)

    pipeline = dlt.pipeline(**pipeline_kwargs)

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
