variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "europe-southwest1"
}

variable "raw_dataset_id" {
  type    = string
  default = "raw_olist_data"
}

variable "analytics_dataset_base" {
  type    = string
  default = "olist_analytics"
}

variable "staging_bucket_name" {
  type = string
}
