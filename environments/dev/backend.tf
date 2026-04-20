# Backend configuration for remote state
# Uncomment and configure for production use
# terraform {
#   backend "gcs" {
#     bucket = "your-tfstate-bucket"
#     prefix = "terraform/dev"
#   }
# }

# For local development, use local backend
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
