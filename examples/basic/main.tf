terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  common_labels = {
    environment = "example-basic"
    managed-by  = "terraform"
    example     = "basic"
  }

  mcp_sa_member = "serviceAccount:${module.iam.service_account_emails["mcp-sa"]}"
}

module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  service_accounts = {
    mcp-sa = {
      account_id   = "mcp-basic-sa"
      display_name = "Service account for MCP Basic Example"
      description  = "Service account for basic MCP server example"
    }
  }

  bindings = []
}

resource "google_project_iam_member" "firestore_access" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = local.mcp_sa_member
}

resource "google_project_iam_member" "trace_access" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = local.mcp_sa_member
}

module "firestore" {
  source = "../../modules/firestore"

  project_id             = var.project_id
  database_id            = var.firestore_database_id
  location               = var.firestore_location
  delete_protection      = false
  point_in_time_recovery = false
}

module "secrets" {
  source = "../../modules/secrets"

  project_id = var.project_id
  secrets    = var.secrets
  accessors  = [local.mcp_sa_member]
}

module "cloud_run" {
  source = "../../modules/cloud-run"

  name                  = var.mcp_server_name
  region                = var.region
  project_id            = var.project_id
  image                 = var.mcp_server_image
  service_account_email = module.iam.service_account_emails["mcp-sa"]

  min_instances = 0
  max_instances = 2

  cpu             = "250m"
  memory          = "256Mi"
  timeout_seconds = 60
  concurrency     = 80

  ingress               = "all"
  allow_unauthenticated = true

  env_vars = {
    ENVIRONMENT  = "example-basic"
    LOG_LEVEL    = "DEBUG"
    FIRESTORE_DB = module.firestore.database_id
  }

  secret_env_vars = {
    for k, v in var.secrets : k => {
      secret  = v.secret_id
      version = "latest"
    }
  }

  labels = local.common_labels

  invoker_members = []
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_id       = var.project_id
  service_name     = var.mcp_server_name
  service_location = var.region
  alert_email      = var.alert_email

  latency_threshold_ms      = 5000
  error_rate_rps            = 5
  cpu_utilization_threshold = 0.9
}
