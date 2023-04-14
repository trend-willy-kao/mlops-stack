terraform {
  // The `backend` block below configures the s3 backend
  // (docs: https://www.terraform.io/language/settings/backends/s3)
  // for storing Terraform state in an AWS S3 bucket. You can run the setup scripts in mlops-setup-scripts/terraform to
  // provision the S3 bucket referenced below and store appropriate credentials for accessing the bucket from CI/CD.
  backend "gcs" {
    bucket = "gcp-mlops-tfstate"
    prefix = "terraform/prod-state"
  }
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}
