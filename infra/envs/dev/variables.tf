# =============================================================================
# infra/envs/dev/variables.tf
#
# Purpose:
#   Declares all input variables for the dev environment.  Actual values are
#   supplied via terraform.tfvars (copy terraform.tfvars.example and fill in).
#
# Reproducibility – ALL variables below must be reviewed:
#   gcp_project_id        -> CHANGE THIS to your GCP project ID
#   gcp_region            -> CHANGE THIS if your resources are in a different region
#   raw_dataset_id        -> must match BQ_RAW_DATASET in your .env file
#   analytics_dataset_base-> must match BQ_DBT_DATASET in your .env / profiles.yml
#   staging_bucket_name   -> CHANGE THIS; must be globally unique across all GCS
# =============================================================================

# CHANGE THIS: your GCP project ID (e.g. "my-project-123456")
variable "gcp_project_id" {
  type = string
}

# CHANGE THIS if your GCP resources are not in europe-southwest1
variable "gcp_region" {
  type    = string
  default = "europe-southwest1"
}

# Must match the BQ_RAW_DATASET environment variable used by ingestion
variable "raw_dataset_id" {
  type    = string
  default = "raw_olist_data"
}

# Must match BQ_DBT_DATASET in .env / profiles.yml
variable "analytics_dataset_base" {
  type    = string
  default = "olist_analytics"
}

# CHANGE THIS: GCS bucket name for dlt staging – must be globally unique
variable "staging_bucket_name" {
  type = string
}
