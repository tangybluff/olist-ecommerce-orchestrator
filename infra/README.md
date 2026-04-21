# Infrastructure

Terraform baseline for core resources used by this project:

- GCS staging bucket for dlt staged loads
- BigQuery raw dataset
- BigQuery analytics dataset base
- Secret Manager placeholders for Kaggle credentials

## Usage

```bash
cd infra/envs/dev
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Copy `terraform.tfvars.example` to `terraform.tfvars` first.
