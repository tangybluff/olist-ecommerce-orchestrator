# =============================================================================
# infra/envs/dev/main.tf
#
# Purpose:
#   Provisions the minimum GCP infrastructure needed to run the pipeline:
#     1. GCS bucket     – staging area for dlt bulk loads into BigQuery
#     2. BigQuery raw   – dataset where dlt writes the raw Olist tables
#     3. BigQuery analytics – dataset where dbt writes transformed models
#     4. Secret Manager – stores Kaggle credentials securely (populate manually)
#
# Why we need it:
#   Infrastructure-as-Code ensures the environment is reproducible.  Anyone
#   with the right GCP permissions can run `terraform apply` to get an
#   identical setup without clicking through the console.
#
# Reproducibility – change values in terraform.tfvars (NOT here):
#   gcp_project_id      -> your GCP project
#   staging_bucket_name -> globally unique GCS bucket name
# =============================================================================

# GCS bucket used by dlt to stage Parquet files before bulk-loading into BigQuery.
# uniform_bucket_level_access=true disables legacy ACLs (security best practice).
# force_destroy=false prevents accidental deletion when running `terraform destroy`.
resource "google_storage_bucket" "dlt_staging" {
  name                        = var.staging_bucket_name
  location                    = upper(var.gcp_region)
  project                     = var.gcp_project_id
  uniform_bucket_level_access = true
  force_destroy               = false
}

# BigQuery dataset that receives raw, unmodified Olist tables from the dlt pipeline.
resource "google_bigquery_dataset" "raw" {
  dataset_id = var.raw_dataset_id
  project    = var.gcp_project_id
  location   = var.gcp_region
}

# BigQuery dataset where dbt writes all transformed models (staging, intermediate, marts).
# dbt appends schema suffixes (e.g. olist_analytics_staging) so only one base dataset
# is needed here.
resource "google_bigquery_dataset" "analytics" {
  dataset_id = var.analytics_dataset_base
  project    = var.gcp_project_id
  location   = var.gcp_region
}

# Secret Manager secrets are optional and require the Secret Manager API to be
# enabled in your GCP project.  They are commented out here so the pipeline
# can run using the .env file instead.  Uncomment and re-run `terraform apply`
# if you want to store Kaggle credentials in Secret Manager.
#
# resource "google_secret_manager_secret" "kaggle_username" {
#   project   = var.gcp_project_id
#   secret_id = "kaggle-username"
#   replication { auto {} }
# }
#
# resource "google_secret_manager_secret" "kaggle_key" {
#   project   = var.gcp_project_id
#   secret_id = "kaggle-key"
#   replication { auto {} }
# }
