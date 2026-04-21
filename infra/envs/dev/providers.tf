terraform {
  required_version = ">= 1.14.8"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 7.26.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
