# Backend configuration for remote state
# Bucket and prefix are supplied at init time via partial configuration:
#   terraform init -backend-config=bucket=my-tfstate-bucket -backend-config=prefix=terraform/prod
terraform {
  backend "gcs" {}
}
