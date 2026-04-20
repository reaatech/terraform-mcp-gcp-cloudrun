terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# Create service accounts
resource "google_service_account" "this" {
  for_each = var.service_accounts

  account_id   = each.value.account_id
  display_name = each.value.display_name != null ? each.value.display_name : "Service account for ${each.value.account_id}"
  description  = each.value.description != null ? each.value.description : "Managed by Terraform for MCP Cloud Run deployment"
  project      = var.project_id
}

# Project-level IAM bindings
resource "google_project_iam_member" "this" {
  for_each = {
    for binding in var.bindings :
    "${binding.member}-${binding.role}" => binding
    if binding.service == null
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}

# Cloud Run v2 service-specific IAM bindings
resource "google_cloud_run_v2_service_iam_member" "this" {
  for_each = {
    for binding in var.bindings :
    "${binding.service}-${binding.location}-${binding.member}-${binding.role}" => binding
    if binding.service != null
  }

  location = each.value.location
  name     = each.value.service
  project  = var.project_id
  role     = each.value.role
  member   = each.value.member
}
