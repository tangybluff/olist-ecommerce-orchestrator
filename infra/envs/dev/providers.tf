# =============================================================================
# infra/envs/dev/providers.tf
#
# Purpose:
#   Declares the Terraform version constraint and the Google Cloud provider.
#   This ensures all team members use compatible versions of Terraform and
#   the GCP provider, preventing drift between environments.
#
# Reproducibility – change if needed:
#   required_version  -> minimum Terraform CLI version; update when upgrading
#   provider version  -> pinned to avoid breaking changes; bump intentionally
#   project / region  -> read from variables.tf, set via terraform.tfvars
# =============================================================================

terraform {
  required_version = ">= 1.14.8"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 7.26.0"  # Pinned; bump deliberately and re-run `terraform init -upgrade`
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
