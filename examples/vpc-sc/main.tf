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
    environment = "example-vpc"
    managed-by  = "terraform"
    example     = "vpc-sc"
  }

  mcp_sa_member = "serviceAccount:${module.iam.service_account_emails["mcp-sa"]}"
}

module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  service_accounts = {
    mcp-sa = {
      account_id   = "mcp-vpc-sa"
      display_name = "Service account for VPC-SC MCP Example"
      description  = "Service account for MCP server in VPC Service Controls example"
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
  delete_protection      = var.delete_protection
  point_in_time_recovery = var.delete_protection
}

module "cloud_run" {
  source = "../../modules/cloud-run"

  name                  = var.mcp_server_name
  region                = var.region
  project_id            = var.project_id
  image                 = var.mcp_server_image
  service_account_email = module.iam.service_account_emails["mcp-sa"]

  vpc_connector = var.vpc_connector

  min_instances = 1
  max_instances = 10

  cpu             = "1000m"
  memory          = "512Mi"
  timeout_seconds = 60
  concurrency     = 80

  ingress               = "internal"
  allow_unauthenticated = false

  env_vars = {
    ENVIRONMENT             = "example-vpc"
    LOG_LEVEL               = "INFO"
    FIRESTORE_DB            = module.firestore.database_id
    VPC_SERVICE_CONTROLS    = "enabled"
    PRIVATE_SERVICE_CONNECT = "true"
  }

  labels = local.common_labels

  invoker_members = var.invoker_members
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_id       = var.project_id
  service_name     = var.mcp_server_name
  service_location = var.region
  alert_email      = var.alert_email

  latency_threshold_ms      = 2000
  error_rate_rps            = 1
  cpu_utilization_threshold = 0.8
}
