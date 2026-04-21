resource "google_storage_bucket" "dlt_staging" {
  name                        = var.staging_bucket_name
  location                    = upper(var.gcp_region)
  project                     = var.gcp_project_id
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_bigquery_dataset" "raw" {
  dataset_id = var.raw_dataset_id
  project    = var.gcp_project_id
  location   = var.gcp_region
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id = var.analytics_dataset_base
  project    = var.gcp_project_id
  location   = var.gcp_region
}

resource "google_secret_manager_secret" "kaggle_username" {
  project   = var.gcp_project_id
  secret_id = "kaggle-username"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "kaggle_key" {
  project   = var.gcp_project_id
  secret_id = "kaggle-key"

  replication {
    auto {}
  }
}
